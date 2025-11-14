// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {ISilo} from "./ISilo.sol";

interface IPartialLiquidationByDefaulting {
    struct CallParams {
        uint256 collateralSharesTotal;
        uint256 protectedSharesTotal;
        uint256 withdrawAssetsFromCollateral;
        uint256 withdrawAssetsFromProtected;
        uint256 collateralSharesForKeeper;
        uint256 collateralSharesForLenders;
        uint256 protectedSharesForKeeper;
        uint256 protectedSharesForLenders;
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

    /// @dev it can revert in case of huge _withdrawAssetsFromCollateral and when `_liquidationFee * KEEPER_FEE > 1e18` 
    function getKeeperAndLenderSharesSplit(
        address _silo,
        address _shareToken,
        uint256 _liquidationFee,
        uint256 _withdrawAssets,
        ISilo.AssetType _assetType
    ) public view virtual returns (uint256 totalShares, uint256 keeperShares, uint256 lendersShares);

    function LT_MARGIN_FOR_DEFAULTING() external view returns (uint256);

    function LIQUIDATION_LOGIC() external view returns (address);

    function KEEPER_FEE() external view returns (uint256);   
}
