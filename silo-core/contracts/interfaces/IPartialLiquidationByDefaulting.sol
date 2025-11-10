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

    error NoControllerForCollateral();
    error CollateralNotSupportedForDefaulting();
    error InvalidLT();

    /// @notice Function to liquidate insolvent position by distributing user's collateral to lenders
    /// - The caller (liquidator) does not cover any debt. `debtToCover` is amount of debt being liquidated
    ///   based on which amount of `collateralAsset` is calculated to distribute to lenders plus a liquidation fee.
    ///   Liquidation fee is split 80/20 between lenders and liquidator.
    /// @dev this method reverts when:
    /// - `_maxDebtToCover` is zero
    /// - `_user` is solvent and there is no debt to cover
    /// @param _user The address of the borrower getting liquidated
    /// @return withdrawCollateral collateral that was send to `msg.sender`, in case of `_receiveSToken` is TRUE,
    /// `withdrawCollateral` will be estimated, on redeem one can expect this value to be rounded down
    /// @return repayDebtAssets actual debt value that was repaid by `msg.sender`
    function liquidationCallByDefaulting(address _user)
        external
        returns (uint256 withdrawCollateral, uint256 repayDebtAssets);
}
