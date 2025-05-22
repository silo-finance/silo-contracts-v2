// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console2} from "forge-std/console2.sol";


import {Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {Math} from "openzeppelin5/utils/math/Math.sol";

import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {ISilo, IERC3156FlashLender} from "../interfaces/ISilo.sol";
import {IERC3156FlashBorrower} from "../interfaces/IERC3156FlashBorrower.sol";
import {ISiloLeverage} from "../interfaces/ISiloLeverage.sol";

import {ZeroExSwapModule} from "./modules/ZeroExSwapModule.sol";
import {RevenueModule} from "./modules/RevenueModule.sol";

// TODO nonReentrant
// TODO ensure it will that work for Pendle
// TODO is it worth to make swap module external contract and do delegate call? that way we can stay with one SiloLeverage
// and swap module can be picked up by argument
contract SiloLeverage is ISiloLeverage, ZeroExSwapModule, RevenueModule, IERC3156FlashBorrower {
    using SafeERC20 for IERC20;

    bytes32 internal constant _FLASHLOAN_CALLBACK = keccak256("ERC3156FlashBorrower.onFlashLoan");
    uint256 internal constant _DECIMALS = 1e18;

    uint256 internal constant _ACTION_OPEN_LEVERAGE = 1;
    uint256 internal constant _ACTION_CLOSE_LEVERAGE = 2;

    // TODO transient
    uint256 internal __action;
    address internal __flashloanTarget;
    address internal __msgSender;
    uint256 internal __totalDeposit;
    uint256 internal __totalBorrow;
    ISiloConfig internal __siloConfig;

    constructor (address _initialOwner) Ownable(_initialOwner) {}

    /// @inheritdoc ISiloLeverage
    function leverage(
        FlashArgs calldata _flashArgs,
        SwapArgs calldata _swapArgs,
        DepositArgs calldata _depositArgs
    ) external virtual returns (uint256 totalDeposit, uint256 totalBorrow) {
        _setTransient(_depositArgs.silo, _ACTION_OPEN_LEVERAGE, _flashArgs.flashloanTarget);

        bytes memory data = abi.encode(_swapArgs, _depositArgs);

        _executeFlashloan(_flashArgs, data);

        totalDeposit = __totalDeposit;
        totalBorrow = __totalBorrow;

        // transient lock will force design pattern, eg flashloan can not be module
        _resetTransient();
        // TODO: does is worth to add check for delta balance + fee at the end?
    }

    function closeLeverage(
        FlashArgs calldata _flashArgs,
        SwapArgs calldata _swapArgs,
        CloseLeverageArgs calldata _closeLeverageArgs
    ) external virtual {
        _setTransient(_closeLeverageArgs.siloWithCollateral, _ACTION_CLOSE_LEVERAGE, _flashArgs.flashloanTarget);

        bytes memory data = abi.encode(_swapArgs, _closeLeverageArgs);

        _executeFlashloan(_flashArgs, data);

        _resetTransient();
    }

    function _executeFlashloan(FlashArgs memory _flashArgs, bytes memory _data) internal virtual {
        require(IERC3156FlashLender(_flashArgs.flashloanTarget).flashLoan({
            _receiver: this,
            _token: _flashArgs.token,
            _amount: _flashArgs.amount,
            _data: _data
        }), FlashloanFailed());
    }

    function onFlashLoan(
        address _initiator,
        address _borrowToken,
        uint256 _flashloanAmount,
        uint256 _flashloanFee,
        bytes calldata _data
    )
        external
        returns (bytes32)
    {
        // this check prevents call `onFlashLoan` directly
        require(__flashloanTarget == msg.sender, InvalidFlashloanLender());

        // TODO: _initiator check might be redundant, because of how `__flashloanTarget` works, but atm I see no harm to check it
        require(_initiator == address(this), InvalidInitiator());

        if (__action == _ACTION_OPEN_LEVERAGE) _openLeverage(_borrowToken, _flashloanAmount, _flashloanFee, _data);
        else if (__action == _ACTION_CLOSE_LEVERAGE) _closeLeverage(_borrowToken, _flashloanAmount, _flashloanFee, _data);
        else revert UnknownAction();

        return _FLASHLOAN_CALLBACK;
    }

    function _openLeverage(
        address _borrowToken,
        uint256 _flashloanAmount,
        uint256 _flashloanFee,
        bytes calldata _data
    )
        internal
    {
        (
            SwapArgs memory swapArgs,
            DepositArgs memory depositArgs
        ) = abi.decode(_data, (SwapArgs, DepositArgs));


        ISilo borrowSilo = _otherSilo(depositArgs.silo);
        uint256 amountOut = _fillQuote(swapArgs, _flashloanAmount);

        _deposit(depositArgs, amountOut, IERC20(swapArgs.buyToken));
        __totalBorrow = _flashloanAmount + _flashloanFee + leverageFee;

        uint256 leverageFee = calculateLeverageFee(_flashloanAmount);

        borrowSilo.borrow({
            _assets: __totalBorrow,
            _receiver: address(this),
            _borrower: __msgSender
        });

        emit OpenLeverage(__msgSender, depositArgs.amount, _flashloanAmount, __totalBorrow);

        // TODO we could cumulate fees and withdraw later, but it will not save much gas
        // and direct transfer allow us to keep leverage contract clean (not have any tokens)
        if (leverageFee != 0) IERC20(_borrowToken).safeTransfer(revenueReceiver, leverageFee);

        IERC20(_borrowToken).forceApprove(__flashloanTarget, _flashloanAmount + _flashloanFee);
    }

    function _closeLeverage(
        address _debtToken,
        uint256 _flashloanAmount,
        uint256 _flashloanFee,
        bytes calldata _data
    )
        internal
    {
        (
            SwapArgs memory swapArgs,
            CloseLeverageArgs memory closeArgs
        ) = abi.decode(_data, (SwapArgs, CloseLeverageArgs));

        ISilo siloWithDebt = _otherSilo(closeArgs.siloWithCollateral);

        IERC20(_debtToken).forceApprove(address(siloWithDebt), _flashloanAmount);
        siloWithDebt.repayShares(_resolveRepayShareBalanceOfMsgSender(siloWithDebt), __msgSender);

        uint256 redeemShares = _resolveRedeemBalanceOfMsgSender(closeArgs);
        closeArgs.siloWithCollateral.redeem(redeemShares, address(this), __msgSender, closeArgs.collateralType);

        uint256 amountOut = _fillQuote(swapArgs, _flashloanAmount);

        uint256 obligation = _flashloanAmount + _flashloanFee;
        require(amountOut >= obligation, SwapDidNotCoverObligations());

        uint256 change = amountOut - obligation;

        IERC20(_debtToken).safeTransfer(__msgSender, change);

        IERC20(_debtToken).forceApprove(__flashloanTarget, obligation);
    }

    function _deposit(DepositArgs memory _depositArgs, uint256 _swapAmountOut, IERC20 _asset)
        internal
        virtual
    {
        // transfer collateral tokens from borrower
        _asset.safeTransferFrom(__msgSender, address(this), _depositArgs.amount);

        __totalDeposit = _depositArgs.amount + _swapAmountOut;

        _asset.forceApprove(address(_depositArgs.silo), __totalDeposit);
        _depositArgs.silo.deposit(__totalDeposit, __msgSender, _depositArgs.collateralType);
    }
    
    function _resolveRepayShareBalanceOfMsgSender(ISilo _siloWithDebt)
        internal
        view
        virtual
        returns (uint256 repayShareBalance)
    {
        (,, address shareDebtToken) = __siloConfig.getShareTokens(address(_siloWithDebt));
        repayShareBalance = IERC20(shareDebtToken).balanceOf(__msgSender);
    }

    function _resolveRedeemBalanceOfMsgSender(CloseLeverageArgs memory _closeArgs)
        internal
        view
        virtual
        returns (uint256 balanceOf)
    {
        console2.log("__msgSender", __msgSender);
        console2.log("_closeArgs.siloWithCollateral.balanceOf(__msgSender)", _closeArgs.siloWithCollateral.balanceOf(__msgSender));

        if (_closeArgs.collateralType == ISilo.CollateralType.Collateral) {
            return _closeArgs.siloWithCollateral.balanceOf(__msgSender);
        }

        (address protectedShareToken,,) = __siloConfig.getShareTokens(address(_closeArgs.siloWithCollateral));

        balanceOf = ISilo(protectedShareToken).balanceOf(__msgSender);
    }

    function _otherSilo(ISilo _thisSilo) internal view returns (ISilo otherSilo) {
        (address silo0, address silo1) = __siloConfig.getSilos();
        require(address(_thisSilo) == silo0 || address(_thisSilo) == silo1, InvalidSilo());

        otherSilo = ISilo(silo0 == address(_thisSilo) ? silo1 : silo0);
    }

    function _setTransient(ISilo _silo, uint256 _action, address _flashloanTarget) internal {
        __flashloanTarget = _flashloanTarget;
        __action = _action;
        __msgSender = msg.sender;
        __siloConfig = _silo.config();
    }
    
    function _resetTransient() internal {
        __totalDeposit = 0;
        __totalBorrow = 0;
        __flashloanTarget = address(0);
        __action = 0;
        __msgSender = address(0);
    }
}
