// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

/// @notice this is backwards compatible interface
interface ISiloBackwardsCompatible {

    /// @notice Retrieves the total amounts of collateral and debt assets
    /// @return totalCollateralAssets The total amount of assets of type 'Collateral'
    /// @return totalDebtAssets The total amount of debt assets of type 'Debt'
    function getCollateralAndDebtTotalsStorage()
        external
        view
        returns (uint256 totalCollateralAssets, uint256 totalDebtAssets);
}
