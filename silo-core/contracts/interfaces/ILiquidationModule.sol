// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import {ISiloConfig} from "./ISiloConfig.sol";
import {ISilo} from "./ISilo.sol";


interface ILiquidationModule {
    /// @dev debt is keep growing over time, so when dApp use this view to calculate max, tx should never revert
    /// because actual max can be only higher
    function maxLiquidation(address _siloWithDebt, address _borrower)
        external
        view
        returns (uint256 collateralToLiquidate, uint256 debtToRepay);

//    /// @notice Determines if a borrower is solvent
//    /// @param _silo Address of the any silo to check for solvency
//    /// @param _borrower Address of the borrower to check for solvency
//    /// @return True if the borrower is solvent, otherwise false
//    function isSolvent(address _silo, address _borrower) external view returns (bool);

    function isSolvent(
        ISiloConfig.ConfigData calldata _collateralConfig,
        ISiloConfig.ConfigData calldata _debtConfig,
        address _borrower,
        ISilo.AccrueInterestInMemory _accrueInMemory,
        uint256 debtShareBalance
    ) external view returns (bool);

    function isSolvent(
        ISiloConfig.ConfigData calldata _collateralConfig,
        ISiloConfig.ConfigData calldata _debtConfig,
        address _borrower,
        ISilo.AccrueInterestInMemory _accrueInMemory
    ) external view returns (bool);

    /// @notice Determines if a borrower's Loan-to-Value (LTV) ratio is below the maximum allowed LTV
    /// @param _collateralConfig Configuration data for the collateral
    /// @param _debtConfig Configuration data for the debt
    /// @param _borrower Address of the borrower to check against max LTV
    /// @param _accrueInMemory Determines whether or not to consider un-accrued interest in calculations
    /// @return True if the borrower's LTV is below the maximum, false otherwise
    function isBelowMaxLtv(
        ISiloConfig.ConfigData calldata _collateralConfig,
        ISiloConfig.ConfigData calldata _debtConfig,
        address _borrower,
        ISilo.AccrueInterestInMemory _accrueInMemory
    ) external view returns (bool);

}
