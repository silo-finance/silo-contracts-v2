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

    function withdrawFees(
        ISiloConfig _config,
        ISiloFactory _factory,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal {
        ISiloConfig.ConfigData memory configData = _config.getConfig(address(this));

        uint256 earnedFees = _assetStorage[configData.token].daoAndDeployerFees;
        uint256 balanceOf = IERC20Upgradeable(configData.token).balanceOf(address(this));
        if (earnedFees > balanceOf) earnedFees = balanceOf;

        _assetStorage[configData.token].daoAndDeployerFees -= earnedFees;

        (address daoFeeReceiver, address deployerFeeReceiver) = _factory.getFeeReceivers(address(this));

        if (daoFeeReceiver == address(0) && deployerFeeReceiver == address(0)) {
            // just in case, should never happen...
            revert ISilo.NothingToPay();
        } else if (deployerFeeReceiver == address(0)) {
            // deployer was never setup or deployer NFT has been burned
            IERC20Upgradeable(configData.token).safeTransferFrom(address(this), daoFeeReceiver, earnedFees);
        } else if (daoFeeReceiver == address(0)) {
            // should never happen... but we assume DAO does not want to make money so all is going to deployer
            IERC20Upgradeable(configData.token).safeTransferFrom(address(this), deployerFeeReceiver, earnedFees);
        } else {
            // split fees proportionally
            uint256 daoFees = earnedFees * configData.daoFee / (configData.daoFee + configData.deployerFee);
            uint256 deployerFees = earnedFees - daoFees;

            IERC20Upgradeable(configData.token).safeTransferFrom(address(this), daoFeeReceiver, daoFees);
            IERC20Upgradeable(configData.token).safeTransferFrom(address(this), deployerFeeReceiver, deployerFees);
        }
    }

    function flashFee(ISiloConfig _config, address _token, uint256 _amount) internal view returns (uint256 fee) {
        (uint256 flashloanFee, address asset) = _config.getFlashloanFeeWithAsset(address(this));

        if (_token != asset) revert ISilo.Unsupported();

        fee = _amount * flashloanFee;

        unchecked {
            fee /= _PRECISION_DECIMALS;
        }
    }

    function amountWithInterest(address _asset, uint256 _amount, address _model)
        internal
        view
        returns (uint256 amount)
    {
        uint256 rcomp = IInterestRateModel(_model).getCompoundInterestRate(address(this), _asset, block.timestamp);

        // deployer and dao fee can be ignored because interest is fully added to AssetStorage anyway
        amount = _amount + _amount * rcomp / _PRECISION_DECIMALS;
    }

    function liquidity(address _asset, mapping(address => ISilo.AssetStorage) storage _assetStorage)
        internal
        view
        returns (uint256 liquidAssets)
    {
        liquidAssets = _assetStorage[_asset].collateralAssets - _assetStorage[_asset].debtAssets;
    }

    function getTotalAssetsAndTotalShares(
        ISiloConfig.ConfigData memory _configData,
        ISilo.AssetType _assetType,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 totalAssets, uint256 totalShares) {
        if (_assetType == ISilo.AssetType.Collateral) {
            totalAssets = amountWithInterest(
                _configData.token, _assetStorage[_configData.token].collateralAssets, _configData.interestRateModel
            );
            totalShares = IShareToken(_configData.collateralShareToken).totalSupply();
        } else if (_assetType == ISilo.AssetType.Debt) {
            totalAssets = amountWithInterest(
                _configData.token, _assetStorage[_configData.token].debtAssets, _configData.interestRateModel
            );
            totalShares = IShareToken(_configData.debtShareToken).totalSupply();
        } else if (_assetType == ISilo.AssetType.Protected) {
            totalAssets = _assetStorage[_configData.token].protectedAssets;
            totalShares = IShareToken(_configData.protectedShareToken).totalSupply();
        }
    }

    function findShareToken(ISiloConfig.ConfigData memory _configData, ISilo.AssetType _assetType)
        internal
        pure
        returns (IShareToken shareToken)
    {
        if (_assetType == ISilo.AssetType.Protected) shareToken = IShareToken(_configData.protectedShareToken);
        else if (_assetType == ISilo.AssetType.Collateral) shareToken = IShareToken(_configData.collateralShareToken);
        else if (_assetType == ISilo.AssetType.Debt) shareToken = IShareToken(_configData.debtShareToken);
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
