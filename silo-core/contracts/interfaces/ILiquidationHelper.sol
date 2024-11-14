// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {ISilo} from "./ISilo.sol";
import {IPartialLiquidation} from "./IPartialLiquidation.sol";

/// @notice LiquidationHelper IS NOT PART OF THE PROTOCOL. SILO CREATED THIS TOOL, MOSTLY AS AN EXAMPLE.
interface ILiquidationHelper {
    /// @param sellToken The `sellTokenAddress` field from the API response.
    /// @param buyToken The `buyTokenAddress` field from the API response.
    /// @param allowanceTarget The `allowanceTarget` field from the API response.
    /// @param swapCallData The `data` field from the API response.
    struct DexSwapInput {
        address sellToken;
        address allowanceTarget;
        bytes swapCallData;
    }

    /// @param _liquidationHook partial liquidation hook address
    /// @param _user silo borrower address
    /// @param _protectedShareToken address of protected share token of silo with `_user` collateral
    struct LiquidationData {
        IPartialLiquidation hook;
        address collateralAsset;
        address user;
        bool receiveSToken;
        address protectedShareToken;
        address collateralShareToken;
    }

    function executeLiquidation(
        ISilo _flashLoanFrom,
        address _debtAsset,
        uint256 _maxDebtToCover,
        LiquidationData calldata _liquidation,
        DexSwapInput[] calldata _swapsInputs0x
    ) external returns (uint256 withdrawCollateral, uint256 repayDebtAssets);
}
