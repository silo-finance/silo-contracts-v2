// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

interface ISiloLiquidation {
    /// @dev Emitted when a borrower is liquidated.
    /// @param liquidator The address of the liquidator
    /// @param receiveSToken True if the liquidators wants to receive the collateral sTokens, `false` if he wants
    /// to receive the underlying collateral asset directly
    event LiquidationCall(
        address indexed liquidator,
        bool receiveSToken
    );

    error UnexpectedCollateralToken();
    error UnexpectedDebtToken();
    error LiquidityFeeToHi();
    error NoDebtToCover();

    error InvalidSiloForCollateral();
    error UserIsSolvent();
    error InsufficientLiquidation();
    error LiquidationTooBig();
    error Insolvency();
    error OnlySilo();

    /// @dev debt is keep growing over time, so when dApp use this view to calculate max, tx should never revert
    /// because actual max can be only higher
    function maxLiquidation(address _borrower)
        external
        view
        returns (uint256 collateralToLiquidate, uint256 debtToRepay);

    /// @notice Function to liquidate a non-healthy position collateral-wise
    /// - The caller (liquidator) covers `debtToCover` amount of debt of the user getting liquidated, and receives
    ///   a amount of the `collateralAsset` plus a bonus to cover market risk
    /// @param _collateralAsset The address of the underlying asset used as collateral, to receive as result
    /// @param _debtAsset The address of the underlying borrowed asset to be repaid with the liquidation
    /// @param _user The address of the borrower getting liquidated
    /// @param _debtToCover The debt amount of borrowed `asset` the liquidator wants to cover,
    /// in case this amount is too big, it will be reduced to maximum allowed liquidation amount
    /// @param _receiveSToken True if the liquidators wants to receive the collateral sTokens, `false` if he wants
    /// to receive the underlying collateral asset directly
    function liquidationCall(
        address _collateralAsset,
        address _debtAsset,
        address _user,
        uint256 _debtToCover,
        bool _receiveSToken
    ) external;

    // TODO liquidationPreview

    function withdrawCollateralsToLiquidator(
        uint256 _withdrawAssetsFromCollateral,
        uint256 _withdrawAssetsFromProtected,
        address _borrower,
        address _liquidator,
        bool _receiveSToken
    ) external;
}
