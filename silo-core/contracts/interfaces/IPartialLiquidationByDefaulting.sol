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
    error TwoWayMarketNotAllowed();
    error EmptyCollateralShareToken();
    error DeductDefaultedDebtFromCollateralFailed();
    error RepayDebtByDefaultingFailed();
    error InvalidLTConfig0();
    error InvalidLTConfig1();
    error WithdrawSharesForLendersTooHighForDistribution();

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

    /// @dev it can revert in case of assets or shares values close to max uint256
    function getKeeperAndLenderSharesSplit(
        uint256 _assetsToLiquidate,
        ISilo.CollateralType _collateralType
    ) external view returns (uint256 totalSharesToLiquidate, uint256 keeperShares, uint256 lendersShares);

    function LT_MARGIN_FOR_DEFAULTING() external view returns (uint256);

    function LIQUIDATION_LOGIC() external view returns (address);

    function KEEPER_FEE() external view returns (uint256);   
}
