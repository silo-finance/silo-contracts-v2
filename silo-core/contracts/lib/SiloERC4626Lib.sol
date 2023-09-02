// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {SafeERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {MathUpgradeable} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";

import {ISiloOracle} from "../interface/ISiloOracle.sol";
import {IHookReceiver} from "../interface/IHookReceiver.sol";
import {SiloStdLib, ISiloConfig, ISilo, IShareToken, IInterestRateModel} from "./SiloStdLib.sol";
import {SiloSolvencyLib} from "./SiloSolvencyLib.sol";
import {SiloLendingLib} from "./SiloLendingLib.sol";

// solhint-disable ordering
// solhint-disable function-max-lines

library SiloERC4626Lib {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 internal constant _PRECISION_DECIMALS = 1e18;

    error DepositNotPossible();
    error NothingToWithdraw();

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
        bool _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 shares) {
        (ISiloConfig.ConfigData memory configData, address asset) = _config.getConfigWithAsset(address(this));

        SiloStdLib.AssetType assetType = SiloStdLib.AssetType.Collateral;
        if (_isProtected) assetType = SiloStdLib.AssetType.Protected;

        (uint256 totalAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalShares(configData, asset, assetType, _assetStorage);

        return SiloStdLib.convertToShares(_assets, totalAssets, totalShares, MathUpgradeable.Rounding.Down);
    }

    struct DepositCache {
        uint256 totalAssets;
        IShareToken collateralShareToken;
        uint256 totalShares;
    }

    function deposit(
        ISiloConfig _config,
        address _depositor,
        address _receiver,
        uint256 _assets,
        uint256 _shares,
        bool _isProtected,
        bool _isDeposit,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 assets, uint256 shares) {
        (ISiloConfig.SmallConfigData memory smallConfigData, address asset) =
            _config.getSmallConfigWithAsset(address(this));
        ISiloConfig.ConfigData memory configData = smallConfigToConfig(smallConfigData);

        SiloLendingLib.accrueInterest(configData, asset, _assetStorage);

        if (!depositPossible(configData, asset, _receiver)) revert DepositNotPossible();

        DepositCache memory cache;

        if (_isProtected) {
            cache.totalAssets = _assetStorage[asset].protectedAssets;
            cache.collateralShareToken = SiloStdLib.findShareToken(configData, SiloStdLib.AssetType.Protected, asset);
        } else {
            cache.totalAssets = _assetStorage[asset].collateralAssets;
            cache.collateralShareToken = SiloStdLib.findShareToken(configData, SiloStdLib.AssetType.Collateral, asset);
        }

        cache.totalShares = cache.collateralShareToken.totalSupply();

        if (_isDeposit) {
            shares = SiloStdLib.convertToShares(
                _assets, cache.totalAssets, cache.collateralShareToken.totalSupply(), MathUpgradeable.Rounding.Down
            );
            assets = _assets;
        } else {
            shares = _shares;
            assets = SiloStdLib.convertToAssets(
                _shares, cache.totalAssets, cache.collateralShareToken.totalSupply(), MathUpgradeable.Rounding.Up
            );
        }

        /// @dev Transfer tokens before minting. No state changes have been made so far so reentracy does nothing.
        IERC20Upgradeable(asset).safeTransferFrom(_depositor, address(this), assets);

        if (_isProtected) {
            /// @dev `assets` and `totalAssets` can never be more than uint256 because totalSupply cannot be either
            unchecked {
                _assetStorage[asset].protectedAssets = cache.totalAssets + assets;
            }
        } else {
            /// @dev `assets` and `totalAssets` can never be more than uint256 because totalSupply cannot be either
            unchecked {
                _assetStorage[asset].collateralAssets = cache.totalAssets + assets;
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
        bool _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 assets) {
        (ISiloConfig.ConfigData memory configData, address asset) = _config.getConfigWithAsset(address(this));

        SiloStdLib.AssetType assetType = SiloStdLib.AssetType.Collateral;
        if (_isProtected) assetType = SiloStdLib.AssetType.Protected;

        (uint256 totalAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalShares(configData, asset, assetType, _assetStorage);

        return SiloStdLib.convertToAssets(_shares, totalAssets, totalShares, MathUpgradeable.Rounding.Up);
    }

    function mint(
        ISiloConfig _config,
        address _depositor,
        address _receiver,
        uint256 _shares,
        bool _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 assets) {
        (assets,) = deposit(_config, _depositor, _receiver, 0, _shares, _isProtected, true, _assetStorage);
    }

    struct MaxWithdrawCache {
        IShareToken shareToken;
        uint256 totalAssets;
        uint256 debtValue;
        uint256 totalCollateralValue;
        uint256 liquidAssets;
        uint256 protectedAndCollateralAssets;
        uint256 totalShares;
    }

    function maxWithdraw(
        ISiloConfig _config,
        address _owner,
        bool _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 assets, uint256 shares) {
        (ISiloConfig.ConfigData memory configData, address asset) = _config.getConfigWithAsset(address(this));

        MaxWithdrawCache memory cache;

        if (_isProtected) {
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

        (,, cache.debtValue, cache.totalCollateralValue, cache.protectedAndCollateralAssets) =
            SiloSolvencyLib.getLtvAndData(configData, _owner);

        // must deduct debt if exists
        if (cache.debtValue != 0) {
            uint256 lt = asset == configData.token0 ? configData.lt0 : configData.lt1;
            uint256 spareTotalCollateralValue =
                cache.totalCollateralValue - ((cache.debtValue * _PRECISION_DECIMALS) / lt);
            uint256 spareCollateralAssets = (
                ((spareTotalCollateralValue * _PRECISION_DECIMALS) / cache.totalCollateralValue)
                    * cache.protectedAndCollateralAssets
            ) / _PRECISION_DECIMALS;
            uint256 spareCollateralShares = SiloStdLib.convertToShares(
                spareCollateralAssets, cache.totalAssets, cache.totalShares, MathUpgradeable.Rounding.Down
            );

            // if spare collateral is less than balance, return that
            if (spareCollateralShares < shares) {
                shares = spareCollateralShares;
            }
        }

        assets =
            SiloStdLib.convertToAssets(shares, cache.totalAssets, cache.totalShares, MathUpgradeable.Rounding.Down);
        cache.liquidAssets = SiloStdLib.liquidity(asset, _assetStorage);

        if (!_isProtected && assets > cache.liquidAssets) {
            assets = cache.liquidAssets;
            shares = SiloStdLib.convertToShares(
                assets, cache.totalAssets, cache.totalShares, MathUpgradeable.Rounding.Down
            );
        }
    }

    function previewWithdraw(
        ISiloConfig _config,
        uint256 _assets,
        bool _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 shares) {
        (ISiloConfig.ConfigData memory configData, address asset) = _config.getConfigWithAsset(address(this));

        SiloStdLib.AssetType assetType = SiloStdLib.AssetType.Collateral;

        if (_isProtected) {
            assetType = SiloStdLib.AssetType.Protected;
        }

        (uint256 totalAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalShares(configData, asset, assetType, _assetStorage);

        return SiloStdLib.convertToShares(_assets, totalAssets, totalShares, MathUpgradeable.Rounding.Down);
    }

    struct WithdrawCache {
        IShareToken shareToken;
        uint256 totalAssets;
        uint256 totalShares;
        uint256 shareBalance;
    }

    // solhint-disable-next-line code-complexity
    function withdraw(
        ISiloConfig _config,
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        address _owner,
        address _spender,
        bool _isProtected,
        bool _isWithdraw,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 assets, uint256 shares) {
        (ISiloConfig.ConfigData memory configData, address asset) = _config.getConfigWithAsset(address(this));

        WithdrawCache memory cache;

        SiloLendingLib.accrueInterest(configData, asset, _assetStorage);

        if (_isProtected) {
            cache.shareToken = SiloStdLib.findShareToken(configData, SiloStdLib.AssetType.Protected, asset);
            cache.totalAssets = _assetStorage[asset].protectedAssets;
        } else {
            cache.shareToken = SiloStdLib.findShareToken(configData, SiloStdLib.AssetType.Collateral, asset);
            cache.totalAssets = _assetStorage[asset].collateralAssets;
        }

        cache.totalShares = cache.shareToken.totalSupply();
        cache.shareBalance = cache.shareToken.balanceOf(_owner);

        if (_isWithdraw) {
            // it's withdraw so assets are user input
            shares = SiloStdLib.convertToShares(
                _assets, cache.totalAssets, cache.totalShares, MathUpgradeable.Rounding.Down
            );
            assets = _assets;
        } else {
            // it's redeem so shares are user input
            shares = _shares;
            assets = SiloStdLib.convertToAssets(
                _shares, cache.totalAssets, cache.totalShares, MathUpgradeable.Rounding.Down
            );
        }

        if (assets == 0 || cache.shareBalance == 0 || shares == 0) revert NothingToWithdraw();

        // withdraw max
        if (shares > cache.shareBalance) {
            shares = cache.shareBalance;
            assets = SiloStdLib.convertToAssets(
                shares, cache.totalAssets, cache.totalShares, MathUpgradeable.Rounding.Down
            );
        }

        // check liquidity
        if (assets > SiloStdLib.liquidity(asset, _assetStorage)) revert SiloLendingLib.NotEnoughLiquidity();

        if (_isProtected) {
            /// @dev `assets` can never be more then `totalAssets` because we always increase `totalAssets` by
            ///      `assets` and interest
            unchecked {
                _assetStorage[asset].protectedAssets = cache.totalAssets - assets;
            }
        } else {
            /// @dev `assets` can never be more then `totalAssets` because we always increase `totalAssets` by
            ///      `assets` and interest
            unchecked {
                _assetStorage[asset].collateralAssets = cache.totalAssets - assets;
            }
        }

        /// @dev `burn` checks if `_spender` is allowed to withdraw `_owner` assets. `burn` calls hook receiver that
        ///      can potentially reenter but state changes are already completed.
        cache.shareToken.burn(_owner, _spender, shares);
        /// @dev fee-on-transfer is ignored
        IERC20Upgradeable(asset).safeTransferFrom(address(this), _receiver, assets);

        /// @dev `_owner` must be solvent
        if (!SiloSolvencyLib.isSolvent(configData, _owner)) revert SiloLendingLib.NotSolvent();
    }

    function previewRedeem(
        ISiloConfig _config,
        uint256 _shares,
        bool _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) external view returns (uint256 assets) {
        (ISiloConfig.ConfigData memory configData, address asset) = _config.getConfigWithAsset(address(this));

        SiloStdLib.AssetType assetType = SiloStdLib.AssetType.Collateral;
        if (_isProtected) assetType = SiloStdLib.AssetType.Protected;

        (uint256 totalAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalShares(configData, asset, assetType, _assetStorage);

        return SiloStdLib.convertToAssets(_shares, totalAssets, totalShares, MathUpgradeable.Rounding.Down);
    }

    function smallConfigToConfig(ISiloConfig.SmallConfigData memory _smallConfigData)
        public
        pure
        returns (ISiloConfig.ConfigData memory configData)
    {
        configData.daoFee = _smallConfigData.daoFee;
        configData.deployerFee = _smallConfigData.deployerFee;
        configData.token0 = _smallConfigData.token0;
        configData.protectedShareToken0 = _smallConfigData.protectedShareToken0;
        configData.collateralShareToken0 = _smallConfigData.collateralShareToken0;
        configData.debtShareToken0 = _smallConfigData.debtShareToken0;
        configData.interestRateModel0 = _smallConfigData.interestRateModel0;
        configData.token1 = _smallConfigData.token1;
        configData.protectedShareToken1 = _smallConfigData.protectedShareToken1;
        configData.collateralShareToken1 = _smallConfigData.collateralShareToken1;
        configData.debtShareToken1 = _smallConfigData.debtShareToken1;
        configData.interestRateModel1 = _smallConfigData.interestRateModel1;
    }
}
