// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISilo, IERC3156FlashLender} from "silo-core/contracts/interfaces/ISilo.sol";
import {IERC3156FlashBorrower} from "silo-core/contracts/interfaces/IERC3156FlashBorrower.sol";

import {ISilo, IERC4626, IERC3156FlashLender} from "./ISilo.sol";
import {IShareToken} from "./IShareToken.sol";

import {IERC3156FlashBorrower} from "./IERC3156FlashBorrower.sol";
import {ISiloConfig} from "./ISiloConfig.sol";
import {ISiloFactory} from "./ISiloFactory.sol";
import {ISiloOracle} from "./ISiloOracle.sol";

interface ISiloLeverage {
    /// @param _silo Silo address on which we doing leverage
    /// @param _deposit deposit amount that user actually do
    /// @param _collateralType collateral type
    /// @param _multiplier leverage multiplier in 18 decimals, eg x1 == 1e18
    /// @param _flashLoanLender source for flashloan
    /// @param _borrowAmount amount of debt that leverage will create.
    /// This amount will be used to repay flashloan, pay fees and change will be transferred to user
    function leverage(
        ISilo _silo,
        uint256 _deposit,
        ISilo.CollateralType _collateralType,
        uint64 _multiplier,
        IERC3156FlashLender _flashLoanLender,
        uint256 _borrowAmount
    ) external;

    /// @param _silo Silo address on which we doing leverage
    /// @param _deposit deposit amount that user actually do
    /// @param _multiplier leverage multiplier in 18 decimals, eg x1 == 1e18
    /// @param _flashLoanLender source for flashloan
    /// @param _swapSlippage max slippage for swap user will use to generate quote for swap data for leverage
    /// Slippage is taken into consideration for calculate borrow amount, it increases amount of collateral by slippage
    /// to have 100% guarantee that after swap we can cover all expenses
    /// @param _collateralToDebtRatio swap ratio in 18 decimals collateral/debt eg 1ETH/2000USD = 1e18/2000e6 = 500000000e18
    /// this ratio should be calculated based on quote API that will be used for swap for leverage
    /// input amount for quote should be `deposit * leverage` as this will be expected amount to swap.
    /// @return flashLoanAmount flashloan amount that is required for leverage
    /// @return borrowAmount amount of debt that leverage will create
    /// Borrow amount must be enough to:
    /// - cover leverage fee (fee is in debt token)
    /// - after swap it to collateral token cover flashloan repay + flashloan fee
    /// @return finalMultiplier final multiplier of leverage (might be different from input _multiplier)
    function previewLeverage(
        ISilo _silo,
        uint256 _deposit,
        uint64 _multiplier,
        IERC3156FlashLender _flashLoanLender,
        uint64 _swapSlippage,
        uint256 _collateralToDebtRatio
    ) external view returns (
        uint256 flashLoanAmount,
        uint256 borrowAmount,
        uint64 finalMultiplier
    );
//
//    function closeLeverage(
//        ISilo _silo,
//        ISilo.CollateralType _collateralType,
//        IERC3156FlashLender _flashloanLender
//    ) external view virtual override returns (ISilo);
//
//    function onFlashLoan(address _initiator, address _token, uint256 _amount, uint256 _fee, bytes calldata _data)
//        external
//        returns (bytes32);
}
