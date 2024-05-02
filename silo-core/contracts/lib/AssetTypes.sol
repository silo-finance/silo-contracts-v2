// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

// solhint-disable private-vars-leading-underscore
library AssetTypes {
    /// @dev must match value of AssetTypes.Protected
    uint256 internal constant Protected = 0;

    /// @dev must match value of AssetTypes.Collateral
    uint256 internal constant Collateral = 1;

    /// @dev must match value of AssetTypes.Debt
    uint256 internal constant Debt = 2;
}
