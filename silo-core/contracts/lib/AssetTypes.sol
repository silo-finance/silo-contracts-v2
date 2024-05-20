// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ISilo} from "../interfaces/ISilo.sol";

// solhint-disable private-vars-leading-underscore
library AssetTypes {
    uint256 internal constant PROTECTED = uint256(ISilo.AssetType.Protected);

    /// @dev must match value of AssetType.Collateral
    uint256 internal constant COLLATERAL = uint256(ISilo.AssetType.Collateral);

    /// @dev must match value of AssetType.Debt
    uint256 internal constant DEBT = uint256(ISilo.AssetType.Debt);
}
