// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IPartialLiquidation} from "./IPartialLiquidation.sol";

/// @notice LiquidationHelper IS NOT PART OF THE PROTOCOL. SILO CREATED THIS TOOL, MOSTLY AS AN EXAMPLE.
interface ILiquidationHelper {
    /// @param _liquidationHook partial liquidation hook address
    /// @param _user silo borrower address
    /// @param _protectedShareToken address of protected share token of silo with `_user` collateral
    struct LiquidationData {
        IPartialLiquidation hook;
        address user;
        address protectedShareToken;
        address collateralShareToken;
        address collateralAsset;
        bool receiveSToken;
    }
}
