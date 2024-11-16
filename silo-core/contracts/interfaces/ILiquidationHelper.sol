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

    /// @param hook partial liquidation hook address
    /// @param collateralAsset address of underlying collateral token of `user` position
    /// @param user silo borrower address
    struct LiquidationData {
        IPartialLiquidation hook;
        address collateralAsset;
        address user;
    }

    /// @param _flashLoanFrom silo from where we can flashloan `_maxDebtToCover` amount to repay debt
    /// @param _debtAsset address of debt token
    /// @param _maxDebtToCover maximum amount we want to repay, check `IPartialLiquidation.maxLiquidation()`
    /// @param _liquidation see desc for `LiquidationData`
    /// @param _dexSwapInput swap that allow us to go from collateral asset to debt asset, and amount out must be equal
    /// to `_maxDebtToCover` + fee for flashloan, this is optional and required only for two assets position
    function executeLiquidation(
        ISilo _flashLoanFrom,
        address _debtAsset,
        uint256 _maxDebtToCover,
        LiquidationData calldata _liquidation,
        DexSwapInput[] calldata _dexSwapInput
    ) external returns (uint256 withdrawCollateral, uint256 repayDebtAssets);
}
