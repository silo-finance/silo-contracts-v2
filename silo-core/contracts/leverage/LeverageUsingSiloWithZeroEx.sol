// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";

import {RevertLib} from "../lib/RevertLib.sol";

import {ISilo} from "../interfaces/ISilo.sol";
import {ILeverageUsingSiloWithZeroEx} from "../interfaces/ILeverageUsingSiloWithZeroEx.sol";
import {IERC3156FlashBorrower} from "../interfaces/IERC3156FlashBorrower.sol";
import {IERC3156FlashLender} from "../interfaces/IERC3156FlashLender.sol";

import {RevenueModule} from "./modules/RevenueModule.sol";
import {LeverageReentrancy} from "./modules/LeverageReentrancy.sol";

/*
    @notice This contract allow to create and close leverage position using flasnloan and swap.
    It supports 0x interface for swap.
*/
// TODO same asset leverage in phase 2
// TODO events on state changes
// TODO ensure it will that work for Pendle
// and swap module can be picked up by argument
contract LeverageUsingSiloWithZeroEx is
    ILeverageUsingSiloWithZeroEx,
    IERC3156FlashBorrower,
    RevenueModule,
    LeverageReentrancy
{
    using SafeERC20 for IERC20;

    string public constant VERSION = "Leverage with silo flashloan and 0x (or compatible) swap";

    uint256 internal constant _DECIMALS = 1e18;
    bytes32 internal constant _FLASHLOAN_CALLBACK = keccak256("ERC3156FlashBorrower.onFlashLoan");

    constructor (address _initialOwner) Ownable(_initialOwner) {}

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

        // _initiator check might be redundant, because of how `__flashloanTarget` works,
        // but atm I see no harm to check it
        require(_initiator == address(this), InvalidInitiator());

        if (__action == LeverageAction.Open) {
            _openLeverage(_borrowToken, _flashloanAmount, _flashloanFee, _data);
        } else if (__action == LeverageAction.Close) {
            _closeLeverage(_borrowToken, _flashloanAmount, _flashloanFee, _data);
        } else revert UnknownAction();

        // approval for repay flashloan
        _setMaxAllowance(IERC20(_borrowToken), __flashloanTarget, _flashloanAmount + _flashloanFee);

        return _FLASHLOAN_CALLBACK;
    }
    
    /// @inheritdoc ILeverageUsingSiloWithZeroEx
    function openLeveragePosition(
        FlashArgs calldata _flashArgs,
        SwapArgs calldata _swapArgs,
        DepositArgs calldata depositArgs
    )
        external
        virtual
        nonReentrant(depositArgs.silo, LeverageAction.Open, _flashArgs.flashloanTarget)
        returns (uint256 totalDeposit, uint256 totalBorrow)
    {
        require(IERC3156FlashLender(_flashArgs.flashloanTarget).flashLoan({
            _receiver: this,
            _token: _flashArgs.token,
            _amount: _flashArgs.amount,
            _data: abi.encode(_swapArgs, depositArgs)
        }), FlashloanFailed());

        totalDeposit = __totalDeposit;
        totalBorrow = __totalBorrow;
    }

    function closeLeveragePosition(
        FlashArgs calldata _flashArgs,
        SwapArgs calldata _swapArgs,
        CloseLeverageArgs calldata _closeLeverageArgs
    )
        external
        virtual
        nonReentrant(_closeLeverageArgs.siloWithCollateral, LeverageAction.Close, _flashArgs.flashloanTarget)
    {
        require(IERC3156FlashLender(_flashArgs.flashloanTarget).flashLoan({
            _receiver: this,
            _token: _flashArgs.token,
            _amount: _flashArgs.amount,
            _data: abi.encode(_swapArgs, _closeLeverageArgs)
        }), FlashloanFailed());
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

        // swap all flashloan amount into collateral token
        uint256 collateralAmountAfterSwap = _fillQuote(swapArgs, _flashloanAmount);

        uint256 totalAssets = depositArgs.amount + collateralAmountAfterSwap;
        // Fee is taken on totalDeposit = user deposit amount + collateral amount after swap
        uint256 feeForLeverage = _calculateLeverageFee(totalAssets);

        address collateralAsset = depositArgs.silo.asset();

        // deposit with leverage: user collateral + swapped collateral - fee
        // TODO qa if posible that feeForLeverage > collateralAmountAfterSwap
        __totalDeposit = _deposit(depositArgs, collateralAmountAfterSwap - feeForLeverage, collateralAsset);

        ISilo borrowSilo = _resolveOtherSilo(depositArgs.silo);

        __totalBorrow = _flashloanAmount + _flashloanFee;

        // borrow asset wil be used to pay fees
        borrowSilo.borrow({_assets: __totalBorrow, _receiver: address(this), _borrower: __msgSender});

        emit OpenLeverage({
            borrower: __msgSender,
            borrowerDeposit: depositArgs.amount,
            swapAmountOut: collateralAmountAfterSwap,
            flashloanAmount: _flashloanAmount,
            totalDeposit: __totalDeposit,
            totalBorrow: __totalBorrow
        });

        _payLeverageFee(collateralAsset, feeForLeverage);
    }

    function _deposit(DepositArgs memory _depositArgs, uint256 _leverageAmount, address _asset)
        internal
        virtual
        returns (uint256 totalDeposit)
    {
        // transfer collateral tokens from borrower
        IERC20(_asset).safeTransferFrom(__msgSender, address(this), _depositArgs.amount);

        totalDeposit = _depositArgs.amount + _leverageAmount;

        _setMaxAllowance(IERC20(_asset), address(_depositArgs.silo), totalDeposit);

        _depositArgs.silo.deposit(totalDeposit, __msgSender, _depositArgs.collateralType);
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

        ISilo siloWithDebt = _resolveOtherSilo(closeArgs.siloWithCollateral);

        _setMaxAllowance(IERC20(_debtToken), address(siloWithDebt), _flashloanAmount);
        siloWithDebt.repayShares(_getBorrowerTotalShareDebtBalance(siloWithDebt), __msgSender);

        uint256 redeemShares = _getBorrowerTotalShareCollateralBalance(closeArgs);

        uint256 withdrawnDeposit = closeArgs.siloWithCollateral.redeem(
            redeemShares, address(this), __msgSender, closeArgs.collateralType
        );

        // swap collateral to debt to repay flashloan
        uint256 availableDebtAssets = _fillQuote(swapArgs, withdrawnDeposit);

        uint256 obligation = _flashloanAmount + _flashloanFee;
        require(availableDebtAssets >= obligation, SwapDidNotCoverObligations());

        uint256 borrowerDebtChange = availableDebtAssets - obligation;

        emit CloseLeverage(__msgSender, _flashloanAmount, availableDebtAssets, withdrawnDeposit);

        if (borrowerDebtChange != 0) IERC20(_debtToken).safeTransfer(__msgSender, borrowerDebtChange);

        IERC20 collateralAsset = IERC20(closeArgs.siloWithCollateral.asset());
        uint256 collateralToTransfer = collateralAsset.balanceOf(address(this));
        if (collateralToTransfer != 0) collateralAsset.safeTransfer(__msgSender, collateralToTransfer);
    }

    /// @notice Executes a token swap using a prebuilt swap quote
    /// @dev The contract must hold the sell token balance before calling.
    /// @param _swapArgs Struct containing all parameters for executing a swap
    /// @param _approval Amount of sell token to approve before the swap
    /// @return amountOut Amount of buy token received after the swap including any previous balance that contract has
    function _fillQuote(SwapArgs memory _swapArgs, uint256 _approval) internal virtual returns (uint256 amountOut) {
        if (_swapArgs.exchangeProxy == address(0)) revert ExchangeAddressZero();

        // Approve token for spending by the exchange
        IERC20(_swapArgs.sellToken).forceApprove(_swapArgs.allowanceTarget, _approval); // TODO max?

        // Perform low-level call to external exchange proxy
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory data) = _swapArgs.exchangeProxy.call(_swapArgs.swapCallData);
        if (!success) RevertLib.revertBytes(data, SwapCallFailed.selector);

        // Reset approval to 1 to avoid lingering allowances
        IERC20(_swapArgs.sellToken).forceApprove(_swapArgs.allowanceTarget, 1);

        amountOut = IERC20(_swapArgs.buyToken).balanceOf(address(this));
    }

    function _setMaxAllowance(IERC20 _asset, address _spender, uint256 _requiredAmount) internal virtual {
        uint256 allowance = _asset.allowance(address(this), _spender);
        if (allowance < _requiredAmount) _asset.forceApprove(_spender, type(uint256).max);
    }

    function _getBorrowerTotalShareDebtBalance(ISilo _siloWithDebt)
        internal
        view
        virtual
        returns (uint256 repayShareBalance)
    {
        (,, address shareDebtToken) = __siloConfig.getShareTokens(address(_siloWithDebt));
        repayShareBalance = IERC20(shareDebtToken).balanceOf(__msgSender);
    }

    function _getBorrowerTotalShareCollateralBalance(CloseLeverageArgs memory closeArgs)
        internal
        view
        virtual
        returns (uint256 balanceOf)
    {
        if (closeArgs.collateralType == ISilo.CollateralType.Collateral) {
            return closeArgs.siloWithCollateral.balanceOf(__msgSender);
        }

        (address protectedShareToken,,) = __siloConfig.getShareTokens(address(closeArgs.siloWithCollateral));

        balanceOf = ISilo(protectedShareToken).balanceOf(__msgSender);
    }

    function _resolveOtherSilo(ISilo _thisSilo) internal view returns (ISilo otherSilo) {
        (address silo0, address silo1) = __siloConfig.getSilos();
        require(address(_thisSilo) == silo0 || address(_thisSilo) == silo1, InvalidSilo());

        otherSilo = ISilo(silo0 == address(_thisSilo) ? silo1 : silo0);
    }
}
