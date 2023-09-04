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

    enum AssetType {
        Protected,
        Collateral,
        Debt
    }

    uint256 internal constant _PRECISION_DECIMALS = 1e18;

    error WrongToken();
    error OutOfBounds();
    error NothingToPay();

    function withdrawFees(
        ISiloConfig _config,
        ISiloFactory _factory,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal {
        (ISiloConfig.ConfigData memory configData, address asset) = _config.getConfigWithAsset(address(this));

        uint256 earnedFees = _assetStorage[asset].daoAndDeployerFees;
        uint256 balanceOf = IERC20Upgradeable(asset).balanceOf(address(this));
        if (earnedFees > balanceOf) earnedFees = balanceOf;

        _assetStorage[asset].daoAndDeployerFees -= earnedFees;

        (address daoFeeReceiver, address deployerFeeReceiver) = _factory.getFeeReceivers(address(this));

        if (daoFeeReceiver == address(0) && deployerFeeReceiver == address(0)) {
            // just in case, should never happen...
            revert NothingToPay();
        } else if (deployerFeeReceiver == address(0)) {
            // deployer was never setup or deployer NFT has been burned
            IERC20Upgradeable(asset).safeTransferFrom(address(this), daoFeeReceiver, earnedFees);
        } else if (daoFeeReceiver == address(0)) {
            // should never happen... but we assume DAO does not want to make money so all is going to deployer
            IERC20Upgradeable(asset).safeTransferFrom(address(this), deployerFeeReceiver, earnedFees);
        } else {
            // split fees proportionally
            uint256 daoFees = earnedFees * configData.daoFee / (configData.daoFee + configData.deployerFee);
            uint256 deployerFees = earnedFees - daoFees;

            IERC20Upgradeable(asset).safeTransferFrom(address(this), daoFeeReceiver, daoFees);
            IERC20Upgradeable(asset).safeTransferFrom(address(this), deployerFeeReceiver, deployerFees);
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
        address _asset,
        AssetType _assetType,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 totalAssets, uint256 totalShares) {
        IShareToken shareToken = findShareToken(_configData, _assetType, _asset);
        totalShares = shareToken.totalSupply();

        if (_assetType == AssetType.Collateral) {
            totalAssets =
                amountWithInterest(_asset, _assetStorage[_asset].collateralAssets, findModel(_configData, _asset));
        } else if (_assetType == AssetType.Debt) {
            totalAssets = amountWithInterest(_asset, _assetStorage[_asset].debtAssets, findModel(_configData, _asset));
        } else if (_assetType == AssetType.Protected) {
            totalAssets = _assetStorage[_asset].protectedAssets;
        }
    }

    // solhint-disable-next-line code-complexity
    function findShareToken(ISiloConfig.ConfigData memory _configData, AssetType _assetType, address _asset)
        internal
        pure
        returns (IShareToken shareToken)
    {
        if (_configData.token0 == _asset) {
            if (_assetType == AssetType.Protected) return IShareToken(_configData.protectedShareToken0);
            else if (_assetType == AssetType.Collateral) return IShareToken(_configData.collateralShareToken0);
            else if (_assetType == AssetType.Debt) return IShareToken(_configData.debtShareToken0);
        } else if (_configData.token1 == _asset) {
            if (_assetType == AssetType.Protected) return IShareToken(_configData.protectedShareToken1);
            else if (_assetType == AssetType.Collateral) return IShareToken(_configData.collateralShareToken1);
            else if (_assetType == AssetType.Debt) return IShareToken(_configData.debtShareToken1);
        } else {
            revert WrongToken();
        }
    }

    function findModel(ISiloConfig.ConfigData memory _configData, address _asset) internal pure returns (address) {
        if (_configData.token0 == _asset) {
            return _configData.interestRateModel0;
        } else if (_configData.token1 == _asset) {
            return _configData.interestRateModel1;
        } else {
            revert WrongToken();
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
