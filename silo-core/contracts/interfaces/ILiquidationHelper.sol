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
        address protectedShareToken;
        address collateralShareToken;
    }

    /// @param _flashLoanFrom silo from where we can flashloan `_maxDebtToCover` amount to repay debt
    /// @param _debtAsset address of debt token
    /// @param _maxDebtToCover maximum amount we want to repay, check `IPartialLiquidation.maxLiquidation()`
    /// @param _liquidation see desc for `LiquidationData`
    /// @param _dexSwapInput swap that allow us to go from collateral asse to debt asset, and amount out must be equal
    /// to `_maxDebtToCover` + fee for flashloan
    function executeLiquidation(
        ISilo _flashLoanFrom,
        address _debtAsset,
        uint256 _maxDebtToCover,
        LiquidationData calldata _liquidation,
        DexSwapInput[] calldata _dexSwapInput
    ) external returns (uint256 withdrawCollateral, uint256 repayDebtAssets);
}
