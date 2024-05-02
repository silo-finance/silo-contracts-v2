// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

// solhint-disable private-vars-leading-underscore
library AssetTypes {
    /// @dev must match value of AssetType.Protected
    uint256 internal constant PROTECTED = 0;

    /// @dev must match value of AssetType.Collateral
    uint256 internal constant COLLATERAL = 1;

    /// @dev must match value of AssetType.Debt
    uint256 internal constant DEBT = 2;
}
