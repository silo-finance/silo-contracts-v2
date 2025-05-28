// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";

import {RevertLib} from "../lib/RevertLib.sol";

import {ISilo} from "../interfaces/ISilo.sol";
import {ILeverageUsingSilo} from "../interfaces/ILeverageUsingSilo.sol";
import {IERC3156FlashBorrower} from "../interfaces/IERC3156FlashBorrower.sol";
import {IERC3156FlashLender} from "../interfaces/IERC3156FlashLender.sol";

import {RevenueModule} from "./modules/RevenueModule.sol";
import {LeverageTxState} from "./modules/LeverageTxState.sol";


// TODO same asset leverage in phase 2
// TODO events on state changes
// TODO ensure it will that work for Pendle
// TODO triple check approvals
//- Leverage contract should never have any tokens
//- close should repay all debt (if position solvent?)
abstract contract LeverageUsingSilo is
    ILeverageUsingSilo,
    IERC3156FlashBorrower,
    RevenueModule,
LeverageTxState
{
    using SafeERC20 for IERC20;

    uint256 internal constant _DECIMALS = 1e18;
    bytes32 internal constant _FLASHLOAN_CALLBACK = keccak256("ERC3156FlashBorrower.onFlashLoan");

    /// @inheritdoc IERC3156FlashBorrower
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
            _openLeverage(_flashloanAmount, _flashloanFee, _data);
        } else if (__action == LeverageAction.Close) {
            _closeLeverage(_borrowToken, _flashloanAmount, _flashloanFee, _data);
        } else revert UnknownAction();

        // approval for repay flashloan
        _setMaxAllowance(IERC20(_borrowToken), __flashloanTarget, _flashloanAmount + _flashloanFee);

        return _FLASHLOAN_CALLBACK;
    }
    
    /// @inheritdoc ILeverageUsingSilo
    function openLeveragePosition(
        FlashArgs calldata _flashArgs,
        bytes calldata _swapArgs,
        DepositArgs calldata _depositArgs
    )
        external
        virtual
        atomicTxFlow(_depositArgs.silo, LeverageAction.Open, _flashArgs.flashloanTarget)
        returns (uint256 totalDeposit, uint256 totalBorrow)
    {
        require(IERC3156FlashLender(_flashArgs.flashloanTarget).flashLoan({
            _receiver: this,
            _token: ISilo(_flashArgs.flashloanTarget).asset(),
            _amount: _flashArgs.amount,
            _data: abi.encode(_swapArgs, _depositArgs)
        }), FlashloanFailed());

        totalDeposit = __totalDeposit;
        totalBorrow = __totalBorrow;
    }

    function closeLeveragePosition(
        FlashArgs calldata _flashArgs,
        bytes calldata _swapArgs,
        CloseLeverageArgs calldata _closeArgs
    )
        external
        virtual
        atomicTxFlow(_closeArgs.siloWithCollateral, LeverageAction.Close, _flashArgs.flashloanTarget)
    {
        require(IERC3156FlashLender(_flashArgs.flashloanTarget).flashLoan({
            _receiver: this,
            _token: ISilo(_flashArgs.flashloanTarget).asset(),
            _amount: _flashArgs.amount,
            _data: abi.encode(_swapArgs, _closeArgs)
        }), FlashloanFailed());
    }

    function _openLeverage(
        uint256 _flashloanAmount,
        uint256 _flashloanFee,
        bytes calldata _data
    )
        internal
    {
        (
            bytes memory swapArgs,
            DepositArgs memory depositArgs
        ) = abi.decode(_data, (bytes, DepositArgs));

        // swap all flashloan amount into collateral token
        uint256 collateralAmountAfterSwap = _fillQuote(swapArgs, _flashloanAmount);

        uint256 totalAssets = depositArgs.amount + collateralAmountAfterSwap;
        // Fee is taken on totalDeposit = user deposit amount + collateral amount after swap
        uint256 feeForLeverage = _calculateLeverageFee(totalAssets);

        address collateralAsset = depositArgs.silo.asset();

        // deposit with leverage: user collateral + swapped collateral - fee
        // TODO qa if posible that feeForLeverage > collateralAmountAfterSwap
        // we could take cut on user original deposit amount to pay fee, but that's the point of doing leverage then?
        require(collateralAmountAfterSwap > feeForLeverage, LeverageToLowToCoverFee());

        __totalDeposit = _deposit({
            _depositArgs: depositArgs,
            _leverageAmount: collateralAmountAfterSwap - feeForLeverage,
            _asset: collateralAsset
        });

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

        _depositArgs.silo.deposit({
            _assets: totalDeposit,
            _receiver: __msgSender,
            _collateralType: _depositArgs.collateralType
        });
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
            bytes memory swapArgs,
            CloseLeverageArgs memory closeArgs
        ) = abi.decode(_data, (bytes, CloseLeverageArgs));

        ISilo siloWithDebt = _resolveOtherSilo(closeArgs.siloWithCollateral);

        _setMaxAllowance({
            _asset: IERC20(_debtToken),
            _spender: address(siloWithDebt),
            _requiredAmount: _flashloanAmount
        });

        siloWithDebt.repayShares(_getBorrowerTotalShareDebtBalance(siloWithDebt), __msgSender);

        uint256 redeemShares = _getBorrowerTotalShareCollateralBalance(closeArgs);

        uint256 withdrawnDeposit = closeArgs.siloWithCollateral.redeem({
            _shares: redeemShares,
            _receiver: address(this),
            _owner: __msgSender,
            _collateralType: closeArgs.collateralType
        });

        // swap collateral to debt to repay flashloan
        uint256 availableDebtAssets = _fillQuote(swapArgs, withdrawnDeposit);

        uint256 obligation = _flashloanAmount + _flashloanFee;
        require(availableDebtAssets >= obligation, SwapDidNotCoverObligations());

        uint256 borrowerDebtChange = availableDebtAssets - obligation;

        emit CloseLeverage({
            borrower: __msgSender,
            flashloanRepay: _flashloanAmount,
            swapAmountOut: availableDebtAssets,
            depositWithdrawn: withdrawnDeposit
        });

        if (borrowerDebtChange != 0) IERC20(_debtToken).safeTransfer(__msgSender, borrowerDebtChange);

        IERC20 collateralAsset = IERC20(closeArgs.siloWithCollateral.asset());
        uint256 collateralToTransfer = collateralAsset.balanceOf(address(this));
        if (collateralToTransfer != 0) collateralAsset.safeTransfer(__msgSender, collateralToTransfer);
    }

    function _fillQuote(bytes memory _swapArgs, uint256 _approval) internal virtual returns (uint256 amountOut);

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
