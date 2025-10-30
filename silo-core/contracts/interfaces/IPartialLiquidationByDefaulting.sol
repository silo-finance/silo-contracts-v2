// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IPartialLiquidationByDefaulting {

    struct CallParams {
        uint256 collateralShares;
        uint256 protectedShares;
        uint256 withdrawAssetsFromCollateral;
        uint256 withdrawAssetsFromCollateralForKeeper;
        uint256 withdrawAssetsFromCollateralForLenders;
        uint256 withdrawAssetsFromProtected;
        uint256 withdrawAssetsFromProtectedForKeeper;
        uint256 withdrawAssetsFromProtectedForLenders;
        bytes4 customError;
    }

    error NoControllerForCollateral(address collateralShareToken);

    /// @notice Function to liquidate insolvent position by distributing user's collateral to lenders
    /// - The caller (liquidator) does not cover any debt. `debtToCover` is amount of debt being liquidated
    ///   based on which amount of `collateralAsset` is calculated to distribute to lenders plus a liquidation fee.
    ///   Liquidation fee is split 80/20 between lenders and liquidator.
    /// @dev this method reverts when:
    /// - `_maxDebtToCover` is zero
    /// - `_collateralAsset` is not `_user` collateral token (note, that user can have both tokens in Silo, but only one
    ///   is for backing debt
    /// - `_debtAsset` is not a token that `_user` borrow
    /// - `_user` is solvent and there is no debt to cover
    /// - `_maxDebtToCover` is set to cover only part of the debt but full liquidation is required
    /// - when not enough liquidity to transfer from `_user` collateral to liquidator
    ///   (use `_receiveSToken == true` in that case)
    /// @param _collateralAsset The address of the underlying asset used as collateral, to receive as result
    /// @param _debtAsset The address of the underlying borrowed asset to be repaid with the liquidation
    /// @param _user The address of the borrower getting liquidated
    /// @param _maxDebtToCover The maximum debt amount of borrowed `asset` the liquidator wants to cover,
    /// in case this amount is too big, it will be reduced to maximum allowed liquidation amount
    /// @return withdrawCollateral collateral that was send to `msg.sender`, in case of `_receiveSToken` is TRUE,
    /// `withdrawCollateral` will be estimated, on redeem one can expect this value to be rounded down
    /// @return repayDebtAssets actual debt value that was repaid by `msg.sender`
    function liquidationCallByDefaulting(
        address _collateralAsset,
        address _debtAsset,
        address _user,
        uint256 _maxDebtToCover
    )
        external
        returns (uint256 withdrawCollateral, uint256 repayDebtAssets);
}
