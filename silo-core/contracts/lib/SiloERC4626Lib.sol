// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {SafeERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {MathUpgradeable} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";

import {SiloStdLib, ISiloConfig, ISilo, IShareToken} from "./SiloStdLib.sol";
import {SiloSolvencyLib} from "./SiloSolvencyLib.sol";
import {SiloLendingLib} from "./SiloLendingLib.sol";

// solhint-disable ordering
// solhint-disable function-max-lines

library SiloERC4626Lib {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using MathUpgradeable for uint256;

    uint256 internal constant _PRECISION_DECIMALS = 1e18;

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

    function depositPossible(ISiloConfig.ConfigData memory _configData, address _asset, address _depositor)
        internal
        view
        returns (bool)
    {
        IShareToken shareDebtToken = SiloStdLib.findShareToken(_configData, SiloStdLib.AssetType.Debt, _asset);
        return shareDebtToken.balanceOf(_depositor) == 0;
    }

    function maxDeposit(ISiloConfig _config, address _receiver) internal view returns (uint256 maxAssets) {
        (ISiloConfig.ConfigData memory configData, address asset) = _config.getConfigWithAsset(address(this));

        if (depositPossible(configData, asset, _receiver)) {
            maxAssets = type(uint256).max - 1;
        }
    }

    function previewDeposit(
        ISiloConfig _config,
        uint256 _assets,
        ISilo.Protected _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 shares) {
        (ISiloConfig.ConfigData memory configData, address asset) = _config.getConfigWithAsset(address(this));

        SiloStdLib.AssetType assetType = SiloStdLib.AssetType.Collateral;
        if (_isProtected == ISilo.Protected.Yes) assetType = SiloStdLib.AssetType.Protected;

        (uint256 totalAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalShares(configData, asset, assetType, _assetStorage);

        return convertToShares(_assets, totalAssets, totalShares, MathUpgradeable.Rounding.Down);
    }

    struct DepositCache {
        uint256 totalAssets;
        IShareToken collateralShareToken;
        uint256 totalShares;
    }

    function deposit(
        ISiloConfig.ConfigData memory _configData,
        address _asset,
        address _depositor,
        address _receiver,
        uint256 _assets,
        uint256 _shares,
        ISilo.Protected _isProtected,
        ISilo.UseAssets _isAssets,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 assets, uint256 shares) {
        DepositCache memory cache;

        if (_isProtected == ISilo.Protected.Yes) {
            cache.totalAssets = _assetStorage[_asset].protectedAssets;
            cache.collateralShareToken =
                SiloStdLib.findShareToken(_configData, SiloStdLib.AssetType.Protected, _asset);
        } else {
            cache.totalAssets = _assetStorage[_asset].collateralAssets;
            cache.collateralShareToken =
                SiloStdLib.findShareToken(_configData, SiloStdLib.AssetType.Collateral, _asset);
        }

        cache.totalShares = cache.collateralShareToken.totalSupply();

        if (_isAssets == ISilo.UseAssets.Yes) {
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

        /// @dev Transfer tokens before minting. No state changes have been made so far so reentracy does nothing.
        IERC20Upgradeable(_asset).safeTransferFrom(_depositor, address(this), assets);

        if (_isProtected == ISilo.Protected.Yes) {
            /// @dev `assets` and `totalAssets` can never be more than uint256 because totalSupply cannot be either
            unchecked {
                _assetStorage[_asset].protectedAssets = cache.totalAssets + assets;
            }
        } else {
            /// @dev `assets` and `totalAssets` can never be more than uint256 because totalSupply cannot be either
            unchecked {
                _assetStorage[_asset].collateralAssets = cache.totalAssets + assets;
            }
        }

        /// @dev Hook receiver is called after `mint` and can reentry but state changes are completed already.
        cache.collateralShareToken.mint(_receiver, _depositor, shares);
    }

    function maxMint(ISiloConfig _config, address _receiver) internal view returns (uint256 maxShares) {
        (ISiloConfig.ConfigData memory configData, address asset) = _config.getConfigWithAsset(address(this));

        if (depositPossible(configData, asset, _receiver)) {
            maxShares = type(uint256).max - 1;
        }
    }

    function previewMint(
        ISiloConfig _config,
        uint256 _shares,
        ISilo.Protected _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 assets) {
        (ISiloConfig.ConfigData memory configData, address asset) = _config.getConfigWithAsset(address(this));

        SiloStdLib.AssetType assetType = SiloStdLib.AssetType.Collateral;
        if (_isProtected == ISilo.Protected.Yes) assetType = SiloStdLib.AssetType.Protected;

        (uint256 totalAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalShares(configData, asset, assetType, _assetStorage);

        return convertToAssets(_shares, totalAssets, totalShares, MathUpgradeable.Rounding.Up);
    }

    struct MaxWithdrawCache {
        IShareToken shareToken;
        uint256 totalAssets;
        uint256 debtValue;
        uint256 totalCollateralValue;
        uint256 liquidAssets;
        uint256 totalShares;
    }

    function maxWithdraw(
        ISiloConfig _config,
        address _owner,
        ISilo.Protected _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 assets, uint256 shares) {
        (ISiloConfig.ConfigData memory configData, address asset) = _config.getConfigWithAsset(address(this));

        MaxWithdrawCache memory cache;

        if (_isProtected == ISilo.Protected.Yes) {
            cache.shareToken = SiloStdLib.findShareToken(configData, SiloStdLib.AssetType.Protected, asset);
            cache.totalAssets = _assetStorage[asset].protectedAssets;
        } else {
            cache.shareToken = SiloStdLib.findShareToken(configData, SiloStdLib.AssetType.Collateral, asset);
            cache.totalAssets = SiloStdLib.amountWithInterest(
                asset, _assetStorage[asset].collateralAssets, SiloStdLib.findModel(configData, asset)
            );
        }

        shares = cache.shareToken.balanceOf(_owner);
        cache.totalShares = cache.shareToken.totalSupply();

        // no deposits of asset
        if (shares == 0) return (0, 0);

        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.getAssetsDataForLtvCalculations(
            configData, _owner, ISilo.OracleType.Solvency, ISilo.AccrueInterestInMemory.Yes
        );

        (cache.debtValue, cache.totalCollateralValue) = SiloSolvencyLib.getPositionValues(ltvData);

        // must deduct debt if exists
        if (cache.debtValue != 0) {
            uint256 lt = asset == configData.token0 ? configData.lt0 : configData.lt1;
            uint256 spareTotalCollateralValue =
                cache.totalCollateralValue - ((cache.debtValue * _PRECISION_DECIMALS) / lt);
            uint256 spareCollateralAssets = (
                ((spareTotalCollateralValue * _PRECISION_DECIMALS) / cache.totalCollateralValue)
                    * ltvData.totalCollateralAssets
            ) / _PRECISION_DECIMALS;
            uint256 spareCollateralShares = convertToShares(
                spareCollateralAssets, cache.totalAssets, cache.totalShares, MathUpgradeable.Rounding.Down
            );

            // if spare collateral is less than balance, return that
            if (spareCollateralShares < shares) {
                shares = spareCollateralShares;
            }
        }

        assets = convertToAssets(shares, cache.totalAssets, cache.totalShares, MathUpgradeable.Rounding.Down);
        cache.liquidAssets = SiloStdLib.liquidity(asset, _assetStorage);

        if (_isProtected == ISilo.Protected.No && assets > cache.liquidAssets) {
            assets = cache.liquidAssets;
            shares = convertToShares(assets, cache.totalAssets, cache.totalShares, MathUpgradeable.Rounding.Down);
        }
    }

    function previewWithdraw(
        ISiloConfig _config,
        uint256 _assets,
        ISilo.Protected _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 shares) {
        (ISiloConfig.ConfigData memory configData, address asset) = _config.getConfigWithAsset(address(this));

        SiloStdLib.AssetType assetType = SiloStdLib.AssetType.Collateral;

        if (_isProtected == ISilo.Protected.Yes) {
            assetType = SiloStdLib.AssetType.Protected;
        }

        (uint256 totalAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalShares(configData, asset, assetType, _assetStorage);

        return convertToShares(_assets, totalAssets, totalShares, MathUpgradeable.Rounding.Down);
    }

    struct WithdrawCache {
        IShareToken shareToken;
        uint256 totalAssets;
        uint256 totalShares;
        uint256 shareBalance;
    }

    // solhint-disable-next-line code-complexity
    function withdraw(
        ISiloConfig.ConfigData memory _configData,
        address _asset,
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        address _owner,
        address _spender,
        ISilo.Protected _isProtected,
        ISilo.UseAssets _isAssets,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 assets, uint256 shares) {
        WithdrawCache memory cache;

        if (_isProtected == ISilo.Protected.Yes) {
            cache.shareToken = SiloStdLib.findShareToken(_configData, SiloStdLib.AssetType.Protected, _asset);
            cache.totalAssets = _assetStorage[_asset].protectedAssets;
        } else {
            cache.shareToken = SiloStdLib.findShareToken(_configData, SiloStdLib.AssetType.Collateral, _asset);
            cache.totalAssets = _assetStorage[_asset].collateralAssets;
        }

        cache.totalShares = cache.shareToken.totalSupply();
        cache.shareBalance = cache.shareToken.balanceOf(_owner);

        if (_isAssets == ISilo.UseAssets.Yes) {
            // it's withdraw so assets are user input
            shares = convertToShares(_assets, cache.totalAssets, cache.totalShares, MathUpgradeable.Rounding.Down);
            assets = _assets;
        } else {
            // it's redeem so shares are user input
            shares = _shares;
            assets = convertToAssets(_shares, cache.totalAssets, cache.totalShares, MathUpgradeable.Rounding.Down);
        }

        if (assets == 0 || cache.shareBalance == 0 || shares == 0) revert ISilo.NothingToWithdraw();

        // withdraw max
        if (shares > cache.shareBalance) {
            shares = cache.shareBalance;
            assets = convertToAssets(shares, cache.totalAssets, cache.totalShares, MathUpgradeable.Rounding.Down);
        }

        // check liquidity
        if (assets > SiloStdLib.liquidity(_asset, _assetStorage)) revert ISilo.NotEnoughLiquidity();

        if (_isProtected == ISilo.Protected.Yes) {
            /// @dev `assets` can never be more then `totalAssets` because we always increase `totalAssets` by
            ///      `assets` and interest
            unchecked {
                _assetStorage[_asset].protectedAssets = cache.totalAssets - assets;
            }
        } else {
            /// @dev `assets` can never be more then `totalAssets` because we always increase `totalAssets` by
            ///      `assets` and interest
            unchecked {
                _assetStorage[_asset].collateralAssets = cache.totalAssets - assets;
            }
        }

        /// @dev `burn` checks if `_spender` is allowed to withdraw `_owner` assets. `burn` calls hook receiver that
        ///      can potentially reenter but state changes are already completed.
        cache.shareToken.burn(_owner, _spender, shares);
        /// @dev fee-on-transfer is ignored
        IERC20Upgradeable(_asset).safeTransferFrom(address(this), _receiver, assets);
    }

    function previewRedeem(
        ISiloConfig _config,
        uint256 _shares,
        ISilo.Protected _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) external view returns (uint256 assets) {
        (ISiloConfig.ConfigData memory configData, address asset) = _config.getConfigWithAsset(address(this));

        SiloStdLib.AssetType assetType = SiloStdLib.AssetType.Collateral;
        if (_isProtected == ISilo.Protected.Yes) assetType = SiloStdLib.AssetType.Protected;

        (uint256 totalAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalShares(configData, asset, assetType, _assetStorage);

        return convertToAssets(_shares, totalAssets, totalShares, MathUpgradeable.Rounding.Down);
    }

    function _decimalsOffset() private pure returns (uint8) {
        return 0;
    }
}
