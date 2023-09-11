// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {SafeERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {MathUpgradeable} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";

import {SiloStdLib, ISiloConfig, ISilo, IShareToken} from "./SiloStdLib.sol";
import {SiloSolvencyLib} from "./SiloSolvencyLib.sol";
import {SiloLendingLib} from "./SiloLendingLib.sol";

// solhint-disable function-max-lines

library SiloERC4626Lib {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using MathUpgradeable for uint256;

    struct WithdrawParams {
        uint256 assets;
        uint256 shares;
        address receiver;
        address owner;
        address spender;
        ISilo.TokenTransfer doTransfer;
        ISilo.AssetType assetType;
    }

    struct DepositCache {
        uint256 totalAssets;
        IShareToken collateralShareToken;
        uint256 totalShares;
    }

    struct WithdrawCache {
        IShareToken shareToken;
        uint256 totalAssets;
        uint256 totalShares;
        uint256 shareBalance;
    }

    uint256 internal constant _PRECISION_DECIMALS = 1e18;

    function deposit(
        ISiloConfig.ConfigData memory _configData,
        address _depositor,
        address _receiver,
        uint256 _assets,
        uint256 _shares,
        ISilo.AssetType _assetType,
        ISilo.UseAssets _useAssets,
        ISilo.TokenTransfer _doTransfer,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 assets, uint256 shares) {
        DepositCache memory cache;

        if (_assetType == ISilo.AssetType.Protected) {
            cache.totalAssets = _assetStorage[_configData.token].protectedAssets;
        } else if (_assetType == ISilo.AssetType.Collateral) {
            cache.totalAssets = _assetStorage[_configData.token].collateralAssets;
        } else {
            revert ISilo.WrongAssetType();
        }

        cache.collateralShareToken = SiloStdLib.findShareToken(_configData, _assetType);
        cache.totalShares = cache.collateralShareToken.totalSupply();

        if (_useAssets == ISilo.UseAssets.Yes) {
            shares = convertToShares(
                _assets, cache.totalAssets, cache.collateralShareToken.totalSupply(), MathUpgradeable.Rounding.Down
            );
            assets = _assets;
        } else {
            shares = _shares;
            assets = convertToAssets(
                _shares, cache.totalAssets, cache.collateralShareToken.totalSupply(), MathUpgradeable.Rounding.Up
            );
        }

        if (_doTransfer == ISilo.TokenTransfer.Yes) {
            // Transfer tokens before minting. No state changes have been made so reentracy does nothing
            IERC20Upgradeable(_configData.token).safeTransferFrom(_depositor, address(this), assets);
        }

        if (_assetType == ISilo.AssetType.Protected) {
            // `assets` and `totalAssets` can never be more than uint256 because totalSupply cannot be either
            unchecked {
                _assetStorage[_configData.token].protectedAssets = cache.totalAssets + assets;
            }
        } else {
            // `assets` and `totalAssets` can never be more than uint256 because totalSupply cannot be either
            unchecked {
                _assetStorage[_configData.token].collateralAssets = cache.totalAssets + assets;
            }
        }

        // Hook receiver is called after `mint` and can reentry but state changes are completed already
        cache.collateralShareToken.mint(_receiver, _depositor, shares);
    }

    function withdraw(
        ISiloConfig.ConfigData memory _configData,
        WithdrawParams memory _params,
        ISilo.UseAssets _useAssets,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 assets, uint256 shares) {
        WithdrawCache memory cache = getWithdrawCache(_configData, _params.owner, _params.assetType, _assetStorage);

        if (_useAssets == ISilo.UseAssets.Yes) {
            // it's withdraw so assets are user input
            shares =
                convertToShares(_params.assets, cache.totalAssets, cache.totalShares, MathUpgradeable.Rounding.Down);
            assets = _params.assets;
        } else {
            // it's redeem so shares are user input
            shares = _params.shares;
            assets =
                convertToAssets(_params.shares, cache.totalAssets, cache.totalShares, MathUpgradeable.Rounding.Down);
        }

        if (assets == 0 || cache.shareBalance == 0 || shares == 0) revert ISilo.NothingToWithdraw();

        // withdraw max
        if (shares > cache.shareBalance) {
            shares = cache.shareBalance;
            assets = convertToAssets(shares, cache.totalAssets, cache.totalShares, MathUpgradeable.Rounding.Down);
        }

        // check liquidity
        if (
            _params.assetType == ISilo.AssetType.Collateral
                && assets > SiloStdLib.liquidity(_configData.token, _assetStorage)
        ) revert ISilo.NotEnoughLiquidity();

        if (_params.assetType == ISilo.AssetType.Protected) {
            // `assets` can never be more then `totalAssets` because we always increase `totalAssets` by
            // `assets` and interest
            unchecked {
                _assetStorage[_configData.token].protectedAssets = cache.totalAssets - assets;
            }
        } else {
            // `assets` can never be more then `totalAssets` because we always increase `totalAssets` by
            // `assets` and interest
            unchecked {
                _assetStorage[_configData.token].collateralAssets = cache.totalAssets - assets;
            }
        }

        // `burn` checks if `_spender` is allowed to withdraw `_owner` assets. `burn` calls hook receiver that
        // can potentially reenter but state changes are already completed.
        cache.shareToken.burn(_params.owner, _params.spender, shares);

        if (_params.doTransfer == ISilo.TokenTransfer.Yes) {
            // fee-on-transfer is ignored
            IERC20Upgradeable(_configData.token).safeTransferFrom(address(this), _params.receiver, assets);
        }
    }

    function getWithdrawCache(
        ISiloConfig.ConfigData memory _configData,
        address _owner,
        ISilo.AssetType _assetType,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (WithdrawCache memory cache) {
        if (_assetType == ISilo.AssetType.Protected) {
            cache.totalAssets = _assetStorage[_configData.token].protectedAssets;
        } else if (_assetType == ISilo.AssetType.Collateral) {
            cache.totalAssets = _assetStorage[_configData.token].collateralAssets;
        } else {
            revert ISilo.WrongAssetType();
        }

        cache.shareToken = SiloStdLib.findShareToken(_configData, _assetType);
        cache.totalShares = cache.shareToken.totalSupply();
        cache.shareBalance = cache.shareToken.balanceOf(_owner);
    }

    function depositPossible(ISiloConfig.ConfigData memory _configData, address _depositor)
        internal
        view
        returns (bool)
    {
        return IShareToken(_configData.debtShareToken).balanceOf(_depositor) == 0;
    }

    function maxDepositOrMint(ISiloConfig _config, address _receiver)
        internal
        view
        returns (uint256 maxAssetsOrShares)
    {
        ISiloConfig.ConfigData memory configData = _config.getConfig(address(this));

        if (SiloERC4626Lib.depositPossible(configData, _receiver)) {
            maxAssetsOrShares = type(uint256).max - 1;
        }
    }

    // TODO: name?
    function preview(
        ISiloConfig _config,
        uint256 _assetsOrShares,
        ISilo.AssetType _assetType,
        ISilo.UseAssets _useAssets,
        MathUpgradeable.Rounding _rounding,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 assetsOrShares) {
        ISiloConfig.ConfigData memory configData = _config.getConfig(address(this));

        (uint256 totalAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalShares(configData, _assetType, _assetStorage);

        if (_useAssets == ISilo.UseAssets.Yes) {
            // using assets means we are converting to shares
            return convertToShares(_assetsOrShares, totalAssets, totalShares, _rounding);
        } else {
            return convertToAssets(_assetsOrShares, totalAssets, totalShares, _rounding);
        }
    }

    function maxWithdraw(
        ISiloConfig _config,
        address _owner,
        ISilo.AssetType _assetType,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 assets, uint256 shares) {
        (ISiloConfig.ConfigData memory configData0, ISiloConfig.ConfigData memory configData1) =
            _config.getConfigs(address(this));

        {
            SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.getAssetsDataForLtvCalculations(
                configData0, configData1, _owner, ISilo.OracleType.Solvency, ISilo.AccrueInterestInMemory.Yes
            );
            (uint256 collateralValue, uint256 debtValue) = SiloSolvencyLib.getPositionValues(ltvData);
            uint256 ltv = debtValue * _PRECISION_DECIMALS / collateralValue;

            // if LTV is higher than LT, user cannot withdraw
            if (ltv >= ltvData.lt) return (0, 0);

            uint256 minimumCollateralValue = debtValue * _PRECISION_DECIMALS / ltvData.lt;
            uint256 spareCollateralValue = collateralValue - minimumCollateralValue;

            // these are total assets (protected + collateral) that _owner can withdraw
            assets = ltvData.totalCollateralAssets * spareCollateralValue / collateralValue;
        }

        (uint256 totalAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalShares(configData0, _assetType, _assetStorage);
        shares = SiloERC4626Lib.convertToShares(assets, totalAssets, totalShares, MathUpgradeable.Rounding.Down);

        uint256 shareBalance;

        if (_assetType == ISilo.AssetType.Protected) {
            shareBalance = IShareToken(configData0.protectedShareToken).balanceOf(_owner);
        } else if (_assetType == ISilo.AssetType.Collateral) {
            shareBalance = IShareToken(configData0.collateralShareToken).balanceOf(_owner);

            uint256 liquidAssets = SiloStdLib.liquidity(configData0.token, _assetStorage);

            // check liquidity
            if (assets > liquidAssets) {
                assets = liquidAssets;
                shares =
                    SiloERC4626Lib.convertToShares(assets, totalAssets, totalShares, MathUpgradeable.Rounding.Down);
            }
        } else {
            revert ISilo.WrongAssetType();
        }

        // check if _owner has enough collateral balance
        if (shares > shareBalance) {
            shares = shareBalance;
            assets = SiloERC4626Lib.convertToAssets(shares, totalAssets, totalShares, MathUpgradeable.Rounding.Down);
        }
    }

    function convertToShares(
        uint256 _assets,
        uint256 _totalAssets,
        uint256 _totalShares,
        MathUpgradeable.Rounding _rounding
    ) internal pure returns (uint256) {
        return _assets.mulDiv(_totalShares + 10 ** _decimalsOffset(), _totalAssets + 1, _rounding);
    }

    function convertToAssets(
        uint256 _shares,
        uint256 _totalAssets,
        uint256 _totalShares,
        MathUpgradeable.Rounding _rounding
    ) internal pure returns (uint256) {
        return _shares.mulDiv(_totalAssets + 1, _totalShares + 10 ** _decimalsOffset(), _rounding);
    }

    function _decimalsOffset() private pure returns (uint8) {
        return 0;
    }
}
