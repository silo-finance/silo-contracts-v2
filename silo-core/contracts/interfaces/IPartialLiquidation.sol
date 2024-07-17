// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import {ISilo} from "./ISilo.sol";

interface IPartialLiquidation {
    struct HookSetup {
        /// @param this is the same as in siloConfig
        address hookReceiver;
        /// @param hooks bitmap
        uint24 hooksBefore;
        /// @param hooks bitmap
        uint24 hooksAfter;
    }

    /// @dev Emitted when a borrower is liquidated.
    /// @param liquidator The address of the liquidator
    /// @param receiveSToken True if the liquidators wants to receive the collateral sTokens, `false` if he wants
    /// to receive the underlying collateral asset directly
    event LiquidationCall(
        address indexed liquidator,
        bool receiveSToken
    );

    /// @dev Revert if provided silo configuration during initialization is empty
    error EmptySiloConfig();
    /// @dev Revert if the hook receiver is already configured/initialized
    error AlreadyConfigured();
    error UnexpectedCollateralToken();
    error UnexpectedDebtToken();
    error LiquidityFeeToHi();
    error NoDebtToCover();
    error DebtToCoverTooSmall();
    error OnlyDelegateCall();
    error InvalidSiloForCollateral();
    error UserIsSolvent();
    error InsufficientLiquidation();
    error LiquidationTooBig();
    error UnknownRatio();

    /// @notice Function to liquidate a non-healthy debt collateral-wise
    /// - The caller (liquidator) covers `debtToCover` amount of debt of the user getting liquidated, and receives
    ///   a amount of the `collateralAsset` plus a bonus to cover market risk
    /// @dev user can use this method to do self liquidation, it that case, check for LT requirements will be ignored
    /// @param _siloWithDebt The address of the silo where the debt it
    /// @param _collateralAsset The address of the underlying asset used as collateral, to receive as result
    /// @param _debtAsset The address of the underlying borrowed asset to be repaid with the liquidation
    /// @param _user The address of the borrower getting liquidated
    /// @param _debtToCover The debt amount of borrowed `asset` the liquidator wants to cover,
    /// in case this amount is too big, it will be reduced to maximum allowed liquidation amount
    /// @param _receiveSToken True if the liquidators wants to receive the collateral sTokens, `false` if he wants
    /// to receive the underlying collateral asset directly
    /// @return withdrawCollateral collateral that was send to `msg.sender`, in case of `_receiveSToken` is TRUE,
    /// `withdrawCollateral` will be estimated, on redeem one can expect this value to be rounded down
    /// @return repayDebtAssets actual debt value that was repayed by `msg.sender`
    function liquidationCall(
        address _siloWithDebt,
        address _collateralAsset,
        address _debtAsset,
        address _user,
        uint256 _debtToCover,
        bool _receiveSToken
    )
        external
        returns (uint256 withdrawCollateral, uint256 repayDebtAssets);

    /// @dev debt is keep growing over time, so when dApp use this view to calculate max, tx should never revert
    /// because actual max can be only higher
    function maxLiquidation(address _siloWithDebt, address _borrower)
        external
        view
        returns (uint256 collateralToLiquidate, uint256 debtToRepay);
}
