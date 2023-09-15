// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {SafeERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {ISiloFactory} from "../interfaces/ISiloFactory.sol";
import {ISilo} from "../interfaces/ISilo.sol";
import {IInterestRateModel} from "../interfaces/IInterestRateModel.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";

library SiloStdLib {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 internal constant _PRECISION_DECIMALS = 1e18;
    uint256 internal constant _BASIS_POINTS = 1e4;

    function withdrawFees(
        ISiloConfig _config,
        ISiloFactory _factory,
        mapping(address => ISilo.AssetStorage) storage _assetStorageMap
    ) internal {
        (
            address daoFeeReceiver,
            address deployerFeeReceiver,
            uint256 daoFeeInBp,
            uint256 deployerFeeInBp,
            address asset
        ) = getFeesAndFeeReceiversWithAsset(_config, _factory);

        uint256 earnedFees = _assetStorageMap[asset].daoAndDeployerFees;
        uint256 balanceOf = IERC20Upgradeable(asset).balanceOf(address(this));
        if (earnedFees > balanceOf) earnedFees = balanceOf;

        _assetStorageMap[asset].daoAndDeployerFees -= earnedFees;

        if (daoFeeReceiver == address(0) && deployerFeeReceiver == address(0)) {
            // just in case, should never happen...
            revert ISilo.NothingToPay();
        } else if (deployerFeeReceiver == address(0)) {
            // deployer was never setup or deployer NFT has been burned
            IERC20Upgradeable(asset).safeTransferFrom(address(this), daoFeeReceiver, earnedFees);
        } else if (daoFeeReceiver == address(0)) {
            // should never happen... but we assume DAO does not want to make money so all is going to deployer
            IERC20Upgradeable(asset).safeTransferFrom(address(this), deployerFeeReceiver, earnedFees);
        } else {
            // split fees proportionally
            uint256 daoFees = earnedFees * daoFeeInBp / (daoFeeInBp + deployerFeeInBp);
            uint256 deployerFees = earnedFees - daoFees;

            IERC20Upgradeable(asset).safeTransferFrom(address(this), daoFeeReceiver, daoFees);
            IERC20Upgradeable(asset).safeTransferFrom(address(this), deployerFeeReceiver, deployerFees);
        }
    }

    function getFeesAndFeeReceiversWithAsset(ISiloConfig _config, ISiloFactory _factory)
        internal
        view
        returns (
            address daoFeeReceiver,
            address deployerFeeReceiver,
            uint256 daoFeeInBp,
            uint256 deployerFeeInBp,
            address asset
        )
    {
        (daoFeeInBp, deployerFeeInBp,, asset) = _config.getFeesWithAsset(address(this));
        (daoFeeReceiver, deployerFeeReceiver) = _factory.getFeeReceivers(address(this));
    }

    /// @notice Returns flash fee amount
    /// @param _config address of config contract for Silo
    /// @param _token for which fee is calculated
    /// @param _amount for which fee is calculated
    /// @return fee flash fee amount
    function flashFee(ISiloConfig _config, address _token, uint256 _amount) internal view returns (uint256 fee) {
        // all user set fees are in basis points
        (,, uint256 flashloanFeeInBp, address asset) = _config.getFeesWithAsset(address(this));

        if (_token != asset) revert ISilo.Unsupported();

        fee = _amount * flashloanFeeInBp;

        unchecked {
            fee /= _BASIS_POINTS;
        }
    }

    /// @notice Returns amount with added interest since last accrue
    /// @dev This function does not know if it should subtract dao's and deployer's fees or not. It is up to a caller
    ///      to set those values. For Collateral calculations fees should be set to correct values. For Debt
    ///      calculations it should be 0s becaue all interest is added to borrowers balances for repayment. This
    ///      function is usefull for view functions that do not accrue interest before doing calculations. To work
    ///      on updated numbers, interest should be added on the fly.
    /// @param _asset for which interest is calculated
    ///  _debtAssets total amount of debt assets from which interest is calculated. Only debt accrues interest.
    /// @param _amount to which add interest
    /// @param _model to use
    ///  _daoFeeInBp dao's fee, set to 0 for Debt calculations, set to correct value for Collateral
    ///  _deployerFeeInBp deployer's fee, set to 0 for Debt calculations, set to correct value for Collateral
    /// @return amount with interest
    function amountWithInterest(address _asset, uint256 _amount, address _model)
        // uint256 _daoFeeInBp,
        // uint256 _deployerFeeInBp
        internal
        view
        returns (uint256 amount)
    {
        uint256 rcomp = IInterestRateModel(_model).getCompoundInterestRate(address(this), _asset, block.timestamp);
        uint256 accruedInterest = _amount * rcomp / _PRECISION_DECIMALS;
        // accruedInterest -= accruedInterest * (_daoFeeInBp + _deployerFeeInBp) / _BASIS_POINTS;

        // deployer and dao fee can be ignored because interest is fully added to AssetStorage anyway
        amount = _amount + accruedInterest;
    }

    /// @notice Returns collateral assets with added interest since last accrue
    /// @dev This function is usefull for view functions that do not accrue interest before doing calculations. To work
    ///      on updated numbers, interest should be added on the fly.
    /// @param _collateralAssets currently saved in the storage
    /// @param _debtAssets currently saved in the storage
    /// @param _rcomp compounded interest rate returned by interest rate model at block.timestamp
    /// @param _daoFeeInBp dao fee defined for asset
    /// @param _deployerFeeInBp deployer fee defined for asset
    /// @return assetsWithInterest collateral assets with interest
    function collateralAssetsWithInterest(
        uint256 _collateralAssets,
        uint256 _debtAssets,
        uint256 _rcomp,
        uint256 _daoFeeInBp,
        uint256 _deployerFeeInBp
    ) internal pure returns (uint256 assetsWithInterest) {
        uint256 accruedInterest = _debtAssets * _rcomp / _PRECISION_DECIMALS;
        accruedInterest -= accruedInterest * (_daoFeeInBp + _deployerFeeInBp) / _BASIS_POINTS;
        assetsWithInterest = _collateralAssets + accruedInterest;
    }

    /// @notice Returns debt assets with added interest since last accrue
    /// @dev This function is usefull for view functions that do not accrue interest before doing calculations. To work
    ///      on updated numbers, interest should be added on the fly.
    /// @param _debtAssets currently saved in the storage
    /// @param _rcomp compounded interest rate returned by interest rate model at block.timestamp
    /// @return assetsWithInterest debt assets with interest
    function debtAssetsWithInterest(uint256 _debtAssets, uint256 _rcomp)
        internal
        pure
        returns (uint256 assetsWithInterest)
    {
        assetsWithInterest = _debtAssets + _debtAssets * _rcomp / _PRECISION_DECIMALS;
    }

    /// @notice Returns available liquidity to be borrowed
    /// @dev Accrued interest is entirely added to `debtAssets` but only part of it is added to `collateralAssets`. The
    ///      difference is DAO's and deployer's cut. That means DAO's and deployer's cut is not considered a borrowable
    ///      liquidity.
    function liquidity(ISilo.AssetStorage storage _assetStorage) internal view returns (uint256 liquidAssets) {
        uint256 collateralAssets = _assetStorage.collateralAssets;
        uint256 debtAssets = _assetStorage.debtAssets;

        if (debtAssets > collateralAssets) return 0;

        unchecked {
            // we just checked the overflow above
            liquidAssets = _assetStorage.collateralAssets - _assetStorage.debtAssets;
        }
    }

    /// @notice Returns totalAssets and totalShares for conversion math (convertToAssets and convertToShares)
    /// @dev This is usefull for view functions that do not accrue interest before doing calculations. To work on
    ///      updated numbers, interest should be added on the fly.
    /// @param _configData for a single token for which to do calculations
    /// @param _assetType used to read proper storage data
    /// @param _assetStorage storage data for asset
    /// @return totalAssets share token used for given asset type
    /// @return totalShares share token used for given asset type
    function getTotalAssetsAndTotalShares(
        ISiloConfig.ConfigData memory _configData,
        ISilo.AssetType _assetType,
        ISilo.AssetStorage storage _assetStorage
    ) internal view returns (uint256 totalAssets, uint256 totalShares) {
        if (_assetType == ISilo.AssetType.Collateral) {
            totalAssets =
                amountWithInterest(_configData.token, _assetStorage.collateralAssets, _configData.interestRateModel);
            totalShares = IShareToken(_configData.collateralShareToken).totalSupply();
        } else if (_assetType == ISilo.AssetType.Debt) {
            totalAssets =
                amountWithInterest(_configData.token, _assetStorage.debtAssets, _configData.interestRateModel);
            totalShares = IShareToken(_configData.debtShareToken).totalSupply();
        } else if (_assetType == ISilo.AssetType.Protected) {
            totalAssets = _assetStorage.protectedAssets;
            totalShares = IShareToken(_configData.protectedShareToken).totalSupply();
        }
    }

    /// @notice Calculates fraction between borrowed and deposited amount of tokens denominated in percentage
    /// @dev It assumes `_dp` = 100%.
    /// @param _dp decimal points used by model
    /// @param _collateralAssets current total deposits for assets
    /// @param _debtAssets current total borrows for assets
    /// @return utilization value, capped to 100%
    /// Limiting utilisation ratio by 100% max will allows us to perform better interest rate computations
    /// and should not affect any other part of protocol.
    function calculateUtilization(uint256 _dp, uint256 _collateralAssets, uint256 _debtAssets)
        internal
        pure
        returns (uint256 utilization)
    {
        if (_collateralAssets == 0 || _debtAssets == 0) return 0;

        utilization = _debtAssets * _dp;
        // _collateralAssets is not 0 based on above check, so it is safe to uncheck this division
        unchecked {
            utilization /= _collateralAssets;
        }

        // cap at 100%
        if (utilization > _dp) utilization = _dp;
    }
}
