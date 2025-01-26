// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {ISilo} from "../interfaces/ISilo.sol";
import {IInterestRateModel} from "../interfaces/IInterestRateModel.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";
import {SiloMathLib} from "./SiloMathLib.sol";

library SiloStdLib {
    using SafeERC20 for IERC20;

    uint256 internal constant _PRECISION_DECIMALS = 1e18;

    /// @notice Returns flash fee amount
    /// @param _config address of config contract for Silo
    /// @param _token for which fee is calculated
    /// @param _amount for which fee is calculated
    /// @return fee flash fee amount
    function flashFee(ISiloConfig _config, address _token, uint256 _amount) internal view returns (uint256 fee) {
        if (_amount == 0) return 0;

        // all user set fees are in 18 decimals points
        (,, uint256 flashloanFee, address asset) = _config.getFeesWithAsset(address(this));
        require(_token == asset, ISilo.UnsupportedFlashloanToken());
        if (flashloanFee == 0) return 0;

        require(type(uint256).max / _amount >= flashloanFee, ISilo.FlashloanAmountTooBig());
        fee = _amount * flashloanFee / _PRECISION_DECIMALS;

        // round up
        if (fee == 0) return 1;
    }

    /// @notice Returns totalAssets and totalShares for conversion math (convertToAssets and convertToShares)
    /// @dev This is useful for view functions that do not accrue interest before doing calculations. To work on
    ///      updated numbers, interest should be added on the fly.
    /// @param _configData for a single token for which to do calculations
    /// @param _assetType used to read proper storage data
    /// @return totalAssets total assets in Silo with interest for given asset type
    /// @return totalShares total shares in Silo for given asset type
    function getTotalAssetsAndTotalSharesWithInterest(
        ISiloConfig.ConfigData memory _configData,
        ISilo.AssetType _assetType
    )
        internal
        view
        returns (uint256 totalAssets, uint256 totalShares)
    {
        if (_assetType == ISilo.AssetType.Protected) {
            totalAssets = ISilo(_configData.silo).getTotalAssetsStorage(ISilo.AssetType.Protected);
            totalShares = IShareToken(_configData.protectedShareToken).totalSupply();
        } else if (_assetType == ISilo.AssetType.Collateral) {
            totalAssets = getTotalCollateralAssetsWithInterest(
                _configData.silo,
                _configData.interestRateModel,
                _configData.daoFee,
                _configData.deployerFee
            );

            totalShares = IShareToken(_configData.collateralShareToken).totalSupply();
        } else { // ISilo.AssetType.Debt
            totalAssets = getTotalDebtAssetsWithInterest(_configData.silo, _configData.interestRateModel);
            totalShares = IShareToken(_configData.debtShareToken).totalSupply();
        }
    }

    /// @notice Retrieves fee amounts in 18 decimals points and their respective receivers along with the asset
    /// @param _silo Silo address
    /// @return daoFeeReceiver Address of the DAO fee receiver
    /// @return deployerFeeReceiver Address of the deployer fee receiver
    /// @return daoFee DAO fee amount in 18 decimals points
    /// @return deployerFee Deployer fee amount in 18 decimals points
    /// @return asset Address of the associated asset
    function getFeesAndFeeReceiversWithAsset(ISilo _silo)
        internal
        view
        returns (
            address daoFeeReceiver,
            address deployerFeeReceiver,
            uint256 daoFee,
            uint256 deployerFee,
            address asset
        )
    {
        (daoFee, deployerFee,, asset) = _silo.config().getFeesWithAsset(address(_silo));
        (daoFeeReceiver, deployerFeeReceiver) = _silo.factory().getFeeReceivers(address(_silo));
    }

    /// @notice Calculates the total collateral assets with accrued interest
    /// @dev Do not use this method when accrueInterest were executed already, in that case total does not change
    /// @param _silo Address of the silo contract
    /// @param _interestRateModel Interest rate model to fetch compound interest rates
    /// @param _daoFee DAO fee in 18 decimals points
    /// @param _deployerFee Deployer fee in 18 decimals points
    /// @return totalCollateralAssetsWithInterest Accumulated collateral amount with interest
    function getTotalCollateralAssetsWithInterest(
        address _silo,
        address _interestRateModel,
        uint256 _daoFee,
        uint256 _deployerFee
    ) internal view returns (uint256 totalCollateralAssetsWithInterest) {
        uint256 rcomp;

        try IInterestRateModel(_interestRateModel).getCompoundInterestRate(_silo, block.timestamp) returns (uint256 r) {
            rcomp = r;
        } catch {
            // do not lock silo
        }

        (uint256 collateralAssets, uint256 debtAssets) = ISilo(_silo).getCollateralAndDebtTotalsStorage();

        (totalCollateralAssetsWithInterest,,,) = SiloMathLib.getCollateralAmountsWithInterest(
            collateralAssets, debtAssets, rcomp, _daoFee, _deployerFee
        );
    }

    /// @param _balanceCached if balance of `_owner` is unknown beforehand, then pass `0`
    function getSharesAndTotalSupply(address _shareToken, address _owner, uint256 _balanceCached)
        internal
        view
        returns (uint256 shares, uint256 totalSupply)
    {
        if (_balanceCached == 0) {
            (shares, totalSupply) = IShareToken(_shareToken).balanceOfAndTotalSupply(_owner);
        } else {
            shares = _balanceCached;
            totalSupply = IShareToken(_shareToken).totalSupply();
        }
    }

    /// @notice Calculates the total debt assets with accrued interest
    /// @param _silo Address of the silo contract
    /// @param _interestRateModel Interest rate model to fetch compound interest rates
    /// @return totalDebtAssetsWithInterest Accumulated debt amount with interest
    function getTotalDebtAssetsWithInterest(address _silo, address _interestRateModel)
        internal
        view
        returns (uint256 totalDebtAssetsWithInterest)
    {
        uint256 rcomp;

        try IInterestRateModel(_interestRateModel).getCompoundInterestRate(_silo, block.timestamp) returns (uint256 r) {
            rcomp = r;
        } catch {
            // do not lock silo
        }

        (
            totalDebtAssetsWithInterest,
        ) = SiloMathLib.getDebtAmountsWithInterest(ISilo(_silo).getTotalAssetsStorage(ISilo.AssetType.Debt), rcomp);
    }
}
