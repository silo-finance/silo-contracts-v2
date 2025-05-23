// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console2} from "forge-std/console2.sol";


import {Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {Math} from "openzeppelin5/utils/math/Math.sol";

import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {ISilo} from "../interfaces/ISilo.sol";
import {ISiloLeverage} from "../interfaces/ISiloLeverage.sol";

import {ZeroExSwapModule} from "./modules/ZeroExSwapModule.sol";
import {RevenueModule} from "./modules/RevenueModule.sol";
import {FlashloanModule} from "./modules/FlashloanModule.sol";

// TODO nonReentrant
// TODO events on state changes
// TODO ensure it will that work for Pendle
// TODO is it worth to make swap module external contract and do delegate call? that way we can stay with one SiloLeverage
// and swap module can be picked up by argument
contract SiloLeverage is ISiloLeverage, ZeroExSwapModule, RevenueModule, FlashloanModule {
    using SafeERC20 for IERC20;

    uint256 internal constant _DECIMALS = 1e18;

    address transient __msgSender;
    uint256 transient __totalDeposit;
    uint256 transient __totalBorrow;
    ISiloConfig transient __siloConfig;

    constructor (address _initialOwner) Ownable(_initialOwner) {}

    /// @inheritdoc ISiloLeverage
    function leverage(
        FlashArgs calldata _flashArgs,
        SwapArgs calldata _swapArgs,
        DepositArgs calldata _depositArgs
    ) external virtual returns (uint256 totalDeposit, uint256 totalBorrow) {
        _setTransient(_depositArgs.silo, LeverageAction.Open, _flashArgs.flashloanTarget);

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
        _setTransient(_closeLeverageArgs.siloWithCollateral, LeverageAction.Close, _flashArgs.flashloanTarget);

        bytes memory data = abi.encode(_swapArgs, _closeLeverageArgs);

        _executeFlashloan(_flashArgs, data);

        _resetTransient();
    }

    function _openLeverage(
        address _borrowToken,
        uint256 _flashloanAmount,
        uint256 _flashloanFee,
        bytes calldata _data
    )
        internal
        override
    {
        (
            SwapArgs memory swapArgs,
            DepositArgs memory depositArgs
        ) = abi.decode(_data, (SwapArgs, DepositArgs));

        // swap all flashloan amount into collateral token
        ISilo borrowSilo = _otherSilo(depositArgs.silo);
        uint256 amountOut = _fillQuote(swapArgs, _flashloanAmount);

        // deposit with leverage
        _deposit(depositArgs, amountOut, IERC20(swapArgs.buyToken));
        __totalBorrow = _flashloanAmount + _flashloanFee + leverageFee;

        // fee is based on flashloan amount, we do not cound user own amount
        uint256 leverageFee = calculateLeverageFee(_flashloanAmount);

        // borrow asset wil be used to pay fees
        borrowSilo.borrow({
            _assets: __totalBorrow,
            _receiver: address(this),
            _borrower: __msgSender
        });

        emit OpenLeverage(__msgSender, depositArgs.amount, _flashloanAmount, __totalBorrow);

        if (leverageFee != 0) IERC20(_borrowToken).safeTransfer(revenueReceiver, leverageFee);

        // approval for repay flashloan
        IERC20(_borrowToken).forceApprove(__flashloanTarget, _flashloanAmount + _flashloanFee);
    }

    function _closeLeverage(
        address _debtToken,
        uint256 _flashloanAmount,
        uint256 _flashloanFee,
        bytes calldata _data
    )
        internal
        override
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

    function _setTransient(ISilo _silo, LeverageAction _action, address _flashloanTarget) internal {
        __flashloanTarget = _flashloanTarget;
        __action = _action;
        __msgSender = msg.sender;
        __siloConfig = _silo.config();
    }
    
    function _resetTransient() internal {
        __totalDeposit = 0;
        __totalBorrow = 0;
        __flashloanTarget = address(0);
        __action = LeverageAction.Undefined;
        __msgSender = address(0);
    }
}
