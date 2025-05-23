// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISiloConfig} from "../../interfaces/ISiloConfig.sol";
import {ISilo} from "../../interfaces/ISilo.sol";
import {ISiloLeverage} from "../../interfaces/ISiloLeverage.sol";

// TODO events on state changes
// TODO ensure it will that work for Pendle
// TODO is it worth to make swap module external contract and do delegate call? that way we can stay with one SiloLeverage
// and swap module can be picked up by argument
abstract contract LeverageModule {
    using SafeERC20 for IERC20;

    uint256 internal constant _DECIMALS = 1e18;

    address internal __msgSender;
    uint256 internal __totalDeposit;
    uint256 internal __totalBorrow;
    ISiloConfig internal __siloConfig;

    // this method is created to separate swap from other actions, it will be easier to override in future
    function _openLeverageFlow(
        ISiloLeverage.DepositArgs memory _depositArgs,
        IERC20 _depositAsset,
        uint256 _swapAmountOut,
        address _borrowToken,
        uint256 _flashloanAmount,
        uint256 _flashloanFee
    )
        internal
        returns (uint totalDeposit, uint256 totalBorrow)
    {
        // deposit with leverage: swapped collateral + user collateral
        totalDeposit = _deposit(_depositArgs, _swapAmountOut, _depositAsset);

        ISilo borrowSilo = _otherSilo(_depositArgs.silo);

        // fee is based on flashloan amount, we do not cound user own amount
        uint256 feeForLeverage = _calculateLeverageFee(_flashloanAmount);

        totalBorrow = _flashloanAmount + _flashloanFee + feeForLeverage;

        // borrow asset wil be used to pay fees
        borrowSilo.borrow({_assets: totalBorrow, _receiver: address(this), _borrower: __msgSender});

        emit ISiloLeverage.OpenLeverage(__msgSender, _depositArgs.amount, _swapAmountOut, _flashloanAmount, totalBorrow);

        _transferFee(_borrowToken, feeForLeverage);
    }

    function _closeLeverageFlowBeforeSwap(
        ISiloLeverage.CloseLeverageArgs memory _closeArgs,
        IERC20 _debtToken,
        uint256 _flashloanAmount
    )
        internal
        returns (uint256 depositWithdrawn)
    {
        ISilo siloWithDebt = _otherSilo(_closeArgs.siloWithCollateral);

        _giveMaxAllowance(_debtToken, address(siloWithDebt), _flashloanAmount);
        siloWithDebt.repayShares(_resolveRepayShareBalanceOfMsgSender(siloWithDebt), __msgSender);

        uint256 redeemShares = _resolveRedeemBalanceOfBorrower(_closeArgs);

        depositWithdrawn = _closeArgs.siloWithCollateral.redeem(
            redeemShares, address(this), __msgSender, _closeArgs.collateralType
        );
    }

    function _closeLeverageFlowAfterSwap(
        uint256 _availableDebtBalance,
        IERC20 _debtToken,
        uint256 _flashloanAmount,
        uint256 _flashloanFee,
        uint256 _depositWithdrawn
    )
        internal
    {
        uint256 obligation = _flashloanAmount + _flashloanFee;
        require(_availableDebtBalance >= obligation, ISiloLeverage.SwapDidNotCoverObligations());

        uint256 borrowerDebtChange = _availableDebtBalance - obligation;

        emit ISiloLeverage.CloseLeverage(__msgSender, _flashloanAmount, _availableDebtBalance, _depositWithdrawn);

        IERC20(_debtToken).safeTransfer(__msgSender, borrowerDebtChange);
    }

    function _deposit(ISiloLeverage.DepositArgs memory _depositArgs, uint256 _swapAmountOut, IERC20 _asset)
        internal
        virtual
        returns (uint256 totalDeposit)
    {
        // transfer collateral tokens from borrower
        _asset.safeTransferFrom(__msgSender, address(this), _depositArgs.amount);

        totalDeposit = _depositArgs.amount + _swapAmountOut;

        _giveMaxAllowance(_asset, address(_depositArgs.silo), totalDeposit);

        _depositArgs.silo.deposit(totalDeposit, __msgSender, _depositArgs.collateralType);
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

    function _resolveRedeemBalanceOfBorrower(ISiloLeverage.CloseLeverageArgs memory _closeArgs)
        internal
        view
        virtual
        returns (uint256 balanceOf)
    {
        if (_closeArgs.collateralType == ISilo.CollateralType.Collateral) {
            return _closeArgs.siloWithCollateral.balanceOf(__msgSender);
        }

        (address protectedShareToken,,) = __siloConfig.getShareTokens(address(_closeArgs.siloWithCollateral));

        balanceOf = ISilo(protectedShareToken).balanceOf(__msgSender);
    }

    function _otherSilo(ISilo _thisSilo) internal view returns (ISilo otherSilo) {
        (address silo0, address silo1) = __siloConfig.getSilos();
        require(address(_thisSilo) == silo0 || address(_thisSilo) == silo1, ISiloLeverage.InvalidSilo());

        otherSilo = ISilo(silo0 == address(_thisSilo) ? silo1 : silo0);
    }

    function _giveMaxAllowance(IERC20 _asset, address _spender, uint256 _requiredAmount) internal virtual {
        uint256 allowance = _asset.allowance(address(this), _spender);
        if (allowance < _requiredAmount) _asset.forceApprove(_spender, type(uint256).max);
    }

    function _calculateLeverageFee(uint256 _amount) internal view virtual returns (uint256 leverageFeeAmount);

    function _transferFee(address _borrowToken, uint256 _leverageFee) internal virtual;
}
