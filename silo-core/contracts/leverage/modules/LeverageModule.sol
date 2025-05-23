// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";

import {ISiloLeverage} from "../../interfaces/ISiloLeverage.sol";
import {ISilo} from "../../interfaces/ISilo.sol";

contract LeverageModule {
    using SafeERC20 for IERC20;

    ISiloConfig internal __siloConfig;

    function _executeLeverageFlow(
        address _borrower,
        address _borrowToken,
        uint256 _flashloanAmount,
        uint256 _flashloanFee,
        uint256 _leverageFee,
        uint256 _swapAmountOut,
        ISiloLeverage.DepositArgs memory _depositArgs
    )
        internal returns (uint256 totalBorrow)
    {
        // deposit with leverage: swapped collateral + user collateral
        uint256 totalDeposit = _deposit(_borrower, _depositArgs, _swapAmountOut);

        ISilo borrowSilo = _otherSilo(_depositArgs.silo);

        totalBorrow = _flashloanAmount + _flashloanFee + _leverageFee;

        // borrow asset wil be used to pay fees
        borrowSilo.borrow({
            _assets: totalBorrow,
            _receiver: address(this),
            _borrower: _borrower
        });

        emit ISiloLeverage.OpenLeverage(_borrower, _depositArgs.amount, _swapAmountOut, _flashloanAmount, totalBorrow);
    }

    function _deposit(address _borrower, ISiloLeverage.DepositArgs memory _depositArgs, uint256 _swapAmountOut)
        internal
        virtual
        returns (uint256 totalDeposit)
    {
        IERC20 _asset = IERC20(_depositArgs.silo.asset());

        // transfer collateral tokens from borrower
        _asset.safeTransferFrom(_borrower, address(this), _depositArgs.amount);

        totalDeposit = _depositArgs.amount + _swapAmountOut;

        _giveMaxAllowance(_asset, address(_depositArgs.silo), totalDeposit);

        _depositArgs.silo.deposit(totalDeposit, _borrower, _depositArgs.collateralType);
    }


    function _closeLeverageFlow(
        address _borrower,
        ISiloLeverage.CloseLeverageArgs memory _closeArgs,
        address _debtToken,
        uint256 _flashloanAmount,
        uint256 _flashloanFee
    )
        internal
    {
        ISilo siloWithDebt = _otherSilo(_closeArgs.siloWithCollateral);

        _giveMaxAllowance(IERC20(_debtToken), address(siloWithDebt), _flashloanAmount);
        siloWithDebt.repayShares(_resolveRepayShareBalanceOfMsgSender(siloWithDebt), _borrower);

        uint256 redeemShares = _resolveRedeemBalanceOfMsgSender(closeArgs);

        uint256 depositWithdrawn = closeArgs.siloWithCollateral.redeem(
            redeemShares, address(this), _borrower, closeArgs.collateralType
        );

        // swap debt to collateral
        uint256 amountOut = _fillQuote(swapArgs, _flashloanAmount);

        uint256 obligation = _flashloanAmount + _flashloanFee;
        require(amountOut >= obligation, SwapDidNotCoverObligations());

        uint256 change = amountOut - obligation;

        emit CloseLeverage(_borrower, _flashloanAmount, amountOut, depositWithdrawn);

        IERC20(_debtToken).safeTransfer(_borrower, change);
    }

    function _giveMaxAllowance(IERC20 _asset, address _spender, uint256 _requiredAmount) internal virtual override {
        uint256 allowance = _asset.allowance(address(this), _spender);
        if (allowance < _requiredAmount) _asset.forceApprove(_spender, type(uint256).max);
    }

    function _otherSilo(ISilo _thisSilo) internal view returns (ISilo otherSilo) {
        (address silo0, address silo1) = __siloConfig.getSilos();
        require(address(_thisSilo) == silo0 || address(_thisSilo) == silo1, ISiloLeverage.InvalidSilo());

        otherSilo = ISilo(silo0 == address(_thisSilo) ? silo1 : silo0);
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
        if (_closeArgs.collateralType == ISilo.CollateralType.Collateral) {
            return _closeArgs.siloWithCollateral.balanceOf(__msgSender);
        }

        (address protectedShareToken,,) = __siloConfig.getShareTokens(address(_closeArgs.siloWithCollateral));

        balanceOf = ISilo(protectedShareToken).balanceOf(__msgSender);
    }
}
