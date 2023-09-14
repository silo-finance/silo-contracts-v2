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

    /// @dev assets amount of assets to withdraw, if 0, means withdraw is based on `shares`
    /// @dev shares depends on `assets` it can be 0 or not
    struct WithdrawParams {
        uint256 assets;
        uint256 shares;
        address receiver;
        address owner;
        address spender;
        ISilo.AssetType assetType;
    }

    struct DepositParams {
        uint256 assets;
        uint256 shares;
        address receiver;
        ISilo.AssetType assetType;
        IShareToken collateralShareToken;
    }

    struct DepositCache {
        uint256 totalAssets;
        uint256 totalShares;
    }

    struct WithdrawCache {
        uint256 totalAssets;
        uint256 totalShares;
        uint256 shareBalance;
    }

    uint256 internal constant _PRECISION_DECIMALS = 1e18;

    /// @param _token if empty, tokens will not be transferred, useful for transition of collateral
    function deposit(
        address _token,
        address _depositor,
        DepositParams memory _depositParams,
        ISilo.AssetStorage storage _assetStorage
    ) internal returns (uint256 assets, uint256 shares) {
        DepositCache memory cache;

        if (_depositParams.assetType == ISilo.AssetType.Protected) {
            cache.totalAssets = _assetStorage.protectedAssets;
        } else {
            cache.totalAssets = _assetStorage.collateralAssets;
        }

        cache.totalShares = _depositParams.collateralShareToken.totalSupply();

        if (_depositParams.assets == 0) {
            shares = _depositParams.shares;
            assets = convertToAssets(
                _depositParams.shares, cache.totalAssets, cache.totalShares, MathUpgradeable.Rounding.Up
            );
        } else {
            shares = convertToShares(
                _depositParams.assets, cache.totalAssets, cache.totalShares, MathUpgradeable.Rounding.Down
            );
            assets = _depositParams.assets;
        }

        if (_token != address(0)) {
            // Transfer tokens before minting. No state changes have been made so reentrancy does nothing
            IERC20Upgradeable(_token).safeTransferFrom(_depositor, address(this), assets);
        }

        if (_depositParams.assetType == ISilo.AssetType.Protected) {
            // `assets` and `totalAssets` can never be more than uint256 because totalSupply cannot be either
            unchecked {
                _assetStorage.protectedAssets = cache.totalAssets + assets;
            }
        } else {
            // `assets` and `totalAssets` can never be more than uint256 because totalSupply cannot be either
            unchecked {
                _assetStorage.collateralAssets = cache.totalAssets + assets;
            }
        }

        // Hook receiver is called after `mint` and can reentry but state changes are completed already
        _depositParams.collateralShareToken.mint(_depositParams.receiver, _depositor, shares);
    }

    /// @param _token token address that we want to withdraw, if empty, withdraw action will be done WITHOUT
    /// actual token transfer
    function withdraw(
        address _token,
        address _shareToken,
        WithdrawParams memory _params,
        ISilo.AssetStorage storage _assetStorage
    ) internal returns (uint256 assets, uint256 shares) {
        WithdrawCache memory cache = getWithdrawCache(_shareToken, _params.owner, _params.assetType, _assetStorage);

        if (_params.assets == 0) {
            // it's redeem so shares are user input
            shares = _params.shares;
            assets =
                convertToAssets(_params.shares, cache.totalAssets, cache.totalShares, MathUpgradeable.Rounding.Down);
        } else {
            // it's withdraw so assets are user input
            shares =
                convertToShares(_params.assets, cache.totalAssets, cache.totalShares, MathUpgradeable.Rounding.Down);
            assets = _params.assets;
        }

        if (assets == 0 || cache.shareBalance == 0 || shares == 0) revert ISilo.NothingToWithdraw();

        // withdraw max
        if (shares > cache.shareBalance) {
            shares = cache.shareBalance;
            assets = convertToAssets(shares, cache.totalAssets, cache.totalShares, MathUpgradeable.Rounding.Down);
        }

        // check liquidity
        if (_params.assetType == ISilo.AssetType.Collateral && assets > SiloStdLib.liquidity(_assetStorage)) {
            revert ISilo.NotEnoughLiquidity();
        }

        if (_params.assetType == ISilo.AssetType.Protected) {
            // `assets` can never be more then `totalAssets` because we always increase `totalAssets` by
            // `assets` and interest
            unchecked {
                _assetStorage.protectedAssets = cache.totalAssets - assets;
            }
        } else {
            // `assets` can never be more then `totalAssets` because we always increase `totalAssets` by
            // `assets` and interest
            unchecked {
                _assetStorage.collateralAssets = cache.totalAssets - assets;
            }
        }

        // `burn` checks if `_spender` is allowed to withdraw `_owner` assets. `burn` calls hook receiver that
        // can potentially reenter but state changes are already completed.
        IShareToken(_shareToken).burn(_params.owner, _params.spender, shares);

        if (_token != address(0)) {
            // fee-on-transfer is ignored
            IERC20Upgradeable(_token).safeTransferFrom(address(this), _params.receiver, assets);
        }
    }

    function getWithdrawCache(
        address _shareToken,
        address _owner,
        ISilo.AssetType _assetType,
        ISilo.AssetStorage storage _assetStorage
    ) internal view returns (WithdrawCache memory cache) {
        if (_assetType == ISilo.AssetType.Protected) {
            cache.totalAssets = _assetStorage.protectedAssets;
        } else if (_assetType == ISilo.AssetType.Collateral) {
            cache.totalAssets = _assetStorage.collateralAssets;
        } else {
            revert ISilo.WrongAssetType();
        }

        cache.totalShares = IShareToken(_shareToken).totalSupply();
        cache.shareBalance = IShareToken(_shareToken).balanceOf(_owner);
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

    /// @param _convertMethod if you using assets then choose `convertToShares`, otherwise `convertToAssets`
    function convertToAssetsOrToShares(
        ISiloConfig _config,
        uint256 _assetsOrShares,
        ISilo.AssetType _assetType,
        function(uint256, uint256, uint256, MathUpgradeable.Rounding) view returns (uint256) _convertMethod,
        MathUpgradeable.Rounding _rounding,
        mapping(address => ISilo.AssetStorage) storage _assetStorageMap
    ) internal view returns (uint256 assetsOrShares) {
        ISiloConfig.ConfigData memory configData = _config.getConfig(address(this));

        (uint256 totalAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalShares(configData, _assetType, _assetStorageMap[configData.token]);

        return _convertMethod(_assetsOrShares, totalAssets, totalShares, _rounding);

//        return _useAssets == ISilo.UseAssets.Yes
//            // using assets means we are converting to shares
//            ? convertToShares(_assetsOrShares, totalAssets, totalShares, _rounding)
//            : convertToAssets(_assetsOrShares, totalAssets, totalShares, _rounding);
    }

    function maxWithdraw(
        ISiloConfig _config,
        address _owner,
        ISilo.AssetType _assetType,
        mapping(address => ISilo.AssetStorage) storage _assetStorageMap
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
            if (ltv >= ltvData.ltInBP) return (0, 0);

            uint256 minimumCollateralValue = debtValue * _PRECISION_DECIMALS / ltvData.ltInBP;
            uint256 spareCollateralValue = collateralValue - minimumCollateralValue;

            // these are total assets (protected + collateral) that _owner can withdraw
            assets = ltvData.totalCollateralAssets * spareCollateralValue / collateralValue;
        }

        (uint256 totalAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalShares(configData0, _assetType, _assetStorageMap[configData0.token]);
        shares = SiloERC4626Lib.convertToShares(assets, totalAssets, totalShares, MathUpgradeable.Rounding.Down);

        uint256 shareBalance;

        if (_assetType == ISilo.AssetType.Protected) {
            shareBalance = IShareToken(configData0.protectedShareToken).balanceOf(_owner);
        } else if (_assetType == ISilo.AssetType.Collateral) {
            shareBalance = IShareToken(configData0.collateralShareToken).balanceOf(_owner);

            uint256 liquidAssets = SiloStdLib.liquidity(_assetStorageMap[configData0.token]);

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
