// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {ISilo} from "./ISilo.sol";
import {IPartialLiquidation} from "./IPartialLiquidation.sol";

/// @notice LiquidationHelper IS NOT PART OF THE PROTOCOL. SILO CREATED THIS TOOL, MOSTLY AS AN EXAMPLE.
interface ILiquidationHelper {
    error UnableToRepayFlashloan();

    /// @param sellToken The `sellTokenAddress` field from the API response.
    /// @param buyToken The `buyTokenAddress` field from the API response.
    /// @param allowanceTarget The `allowanceTarget` field from the API response.
    /// @param swapCallData The `data` field from the API response.
    struct DexSwapInput {
        address sellToken;
        address allowanceTarget;
        bytes swapCallData;
    }

    /// @param hook partial liquidation hook address assigned to silo
    /// you can get hook address by calling: silo.config().getConfig(_silo).hookReceiver
    /// @param collateralAsset address of underlying collateral token of `user` position
    /// @param user silo borrower address
    struct LiquidationData {
        IPartialLiquidation hook;
        address collateralAsset;
        address user;
    }

    /// @param _flashLoanFrom silo from where we can flashloan `_maxDebtToCover` amount of `_debtAsset` to repay debt
    /// @param _debtAsset address of debt token (underlying token)
    /// @param _maxDebtToCover maximum amount we want to repay,
    /// you can use `IPartialLiquidation.maxLiquidation()` to get maximum possible  value
    /// @param _liquidation see desc for `LiquidationData` struct
    /// @param _dexSwapInput swap bytes that allows to swap all collateral assets to debt asset,
    /// this is optional and required only for two assets position
    function executeLiquidation(
        ISilo _flashLoanFrom,
        address _debtAsset,
        uint256 _maxDebtToCover,
        LiquidationData calldata _liquidation,
        DexSwapInput[] calldata _dexSwapInput
    ) external returns (uint256 withdrawCollateral, uint256 repayDebtAssets);
}
