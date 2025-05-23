// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {console2} from "forge-std/console2.sol";


import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISiloConfig} from "../../interfaces/ISiloConfig.sol";
import {ISilo} from "../../interfaces/ISilo.sol";
import {ISiloLeverage} from "../../interfaces/ISiloLeverage.sol";

abstract contract LeverageModule {
    using SafeERC20 for IERC20;

    uint256 internal constant _DECIMALS = 1e18;

    address internal __msgSender;
    uint256 internal __totalDeposit;
    uint256 internal __totalBorrow;
    ISiloConfig internal __siloConfig;

    function _openLeveragePosition(
        ISiloLeverage.DepositArgs memory depositArgs,
        uint256 swapAmountOut,
        address _borrowToken,
        uint256 _flashloanAmount,
        uint256 _flashloanFee,
        bytes calldata _data
    )
        internal
    {
        // deposit with leverage: swapped collateral + user collateral
        _deposit(depositArgs, swapAmountOut);

        // fee is based on flashloan amount, we do not cound user own amount
        uint256 leverageFee = _calculateLeverageFee(_flashloanAmount);

        __totalBorrow = _flashloanAmount + _flashloanFee + leverageFee;

        ISilo borrowSilo = _otherSilo(depositArgs.silo);

        // borrow asset wil be used to pay fees
        borrowSilo.borrow({
            _assets: __totalBorrow,
            _receiver: address(this),
            _borrower: __msgSender
        });

        emit OpenLeverage(__msgSender, depositArgs.amount, swapAmountOut, _flashloanAmount, __totalBorrow);

        if (leverageFee != 0) IERC20(_borrowToken).safeTransfer(revenueReceiver, leverageFee);
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

        _giveMaxAllowance(IERC20(_debtToken), address(siloWithDebt), _flashloanAmount);
        siloWithDebt.repayShares(_resolveRepayShareBalanceOfMsgSender(siloWithDebt), __msgSender);

        uint256 redeemShares = _resolveRedeemBalanceOfMsgSender(closeArgs);

        uint256 depositWithdrawn = closeArgs.siloWithCollateral.redeem(
            redeemShares, address(this), __msgSender, closeArgs.collateralType
        );

        // swap debt to collateral
        uint256 amountOut = _fillQuote(swapArgs, _flashloanAmount);

        uint256 obligation = _flashloanAmount + _flashloanFee;
        require(amountOut >= obligation, SwapDidNotCoverObligations());

        uint256 change = amountOut - obligation;

        emit CloseLeverage(__msgSender, _flashloanAmount, amountOut, depositWithdrawn);

        IERC20(_debtToken).safeTransfer(__msgSender, change);
    }

    function _giveMaxAllowance(IERC20 _asset, address _spender, uint256 _requiredAmount) internal;

    function _deposit(ISiloLeverage.DepositArgs memory _depositArgs, uint256 _swapAmountOut)
        internal
        virtual
    {
        IERC20 asset = IERC20(_depositArgs.silo.asset());

        // transfer collateral tokens from borrower
        _asset.safeTransferFrom(__msgSender, address(this), _depositArgs.amount);

        __totalDeposit = _depositArgs.amount + _swapAmountOut;

        _giveMaxAllowance(_asset, address(_depositArgs.silo), __totalDeposit);

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

    function _resolveRedeemBalanceOfMsgSender(ISiloLeverage.CloseLeverageArgs memory _closeArgs)
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
        require(address(_thisSilo) == silo0 || address(_thisSilo) == silo1, InvalidSilo());

        otherSilo = ISilo(silo0 == address(_thisSilo) ? silo1 : silo0);
    }

    function _calculateLeverageFee(uint256 _amount) internal virtual view returns (uint256 leverageFeeAmount);
}
