// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {SafeERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {MathUpgradeable} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";

import {ISiloOracle} from "../interfaces/ISiloOracle.sol";
import {SiloStdLib, ISiloConfig, ISilo, IShareToken, IInterestRateModel} from "./SiloStdLib.sol";
import {SiloSolvencyLib} from "./SiloSolvencyLib.sol";
import {SiloERC4626Lib} from "./SiloERC4626Lib.sol";

// solhint-disable ordering
// solhint-disable function-max-lines

library SiloLendingLib {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 internal constant _PRECISION_DECIMALS = 1e18;

    function borrowPossible(ISiloConfig.ConfigData memory _configData, address _asset, address _borrower)
        internal
        view
        returns (bool)
    {
        IShareToken protectedShareToken =
            SiloStdLib.findShareToken(_configData, SiloStdLib.AssetType.Protected, _asset);
        IShareToken collateralShareToken =
            SiloStdLib.findShareToken(_configData, SiloStdLib.AssetType.Collateral, _asset);

        uint256 totalCollateralBalance =
            protectedShareToken.balanceOf(_borrower) + collateralShareToken.balanceOf(_borrower);

        bool borrowable = _asset == _configData.token0 ? _configData.borrowable0 : _configData.borrowable1;

        /// @dev token must be marked as borrowable and _borrower cannot have any collateral deposited
        return borrowable && totalCollateralBalance == 0;
    }

    struct TransitionCache {
        IShareToken fromShareToken;
        uint256 fromTotalAssets;
        IShareToken toShareToken;
        uint256 toTotalAssets;
        uint256 fromTotalShares;
        uint256 shareBalance;
    }

    function transition(
        ISiloConfig.ConfigData memory _configData,
        address _asset,
        uint256 _shares,
        address _owner,
        address _spender,
        ISilo.Transition _transition,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 assets, uint256 shares, uint256 toShares) {
        accrueInterest(_configData, _asset, _assetStorage);

        TransitionCache memory cache;

        if (_transition == ISilo.Transition.ToProtected) {
            cache.fromShareToken = SiloStdLib.findShareToken(_configData, SiloStdLib.AssetType.Collateral, _asset);
            cache.fromTotalAssets = _assetStorage[_asset].collateralAssets;
            cache.toShareToken = SiloStdLib.findShareToken(_configData, SiloStdLib.AssetType.Protected, _asset);
            cache.toTotalAssets = _assetStorage[_asset].protectedAssets;
        } else {
            cache.fromShareToken = SiloStdLib.findShareToken(_configData, SiloStdLib.AssetType.Protected, _asset);
            cache.fromTotalAssets = _assetStorage[_asset].protectedAssets;
            cache.toShareToken = SiloStdLib.findShareToken(_configData, SiloStdLib.AssetType.Collateral, _asset);
            cache.toTotalAssets = _assetStorage[_asset].collateralAssets;
        }

        cache.fromTotalShares = cache.fromShareToken.totalSupply();
        cache.shareBalance = cache.fromShareToken.balanceOf(_owner);
        assets = SiloERC4626Lib.convertToAssets(
            _shares, cache.fromTotalAssets, cache.fromTotalShares, MathUpgradeable.Rounding.Down
        );
        shares = _shares;

        if (assets == 0 || cache.shareBalance == 0 || shares == 0) revert ISilo.NothingToWithdraw();

        // withdraw max
        if (cache.shareBalance < shares) {
            shares = cache.shareBalance;
            assets = SiloERC4626Lib.convertToAssets(
                shares, cache.fromTotalAssets, cache.fromTotalShares, MathUpgradeable.Rounding.Down
            );
        }

        if (_transition == ISilo.Transition.ToProtected) {
            /// @dev when moving to protected collateral make sure that there is available liquidity in the Silo.
            ///      If there isn't, disallow transition. Otherwise, users could use it as a way to withdraw other's
            ///      people protected tokens when utilization of the Silo is at 100%.
            if (assets > SiloStdLib.liquidity(_asset, _assetStorage)) revert ISilo.NotEnoughLiquidity();

            _assetStorage[_asset].collateralAssets = cache.fromTotalAssets - assets;
        } else {
            _assetStorage[_asset].protectedAssets = cache.fromTotalAssets - assets;
        }

        /// @dev burn checks if _spender is allowed to transition _owner tokens
        cache.fromShareToken.burn(_owner, _spender, shares);

        /// @dev `burn` and `mint` call hook receiver contract which can possibly reenter. To keep correct state during
        ///      potential reentry, we increase balances after burn as if transition was done in two separate
        ///      transactions.
        if (_transition == ISilo.Transition.ToProtected) {
            _assetStorage[_asset].protectedAssets = cache.toTotalAssets + assets;
        } else {
            _assetStorage[_asset].collateralAssets = cache.toTotalAssets + assets;
        }

        toShares = SiloERC4626Lib.convertToShares(
            assets, cache.toTotalAssets, cache.toShareToken.totalSupply(), MathUpgradeable.Rounding.Down
        );
        cache.toShareToken.mint(_owner, _spender, toShares);
    }

    struct MaxBorrowCache {
        IShareToken protectedShareToken;
        IShareToken collateralShareToken;
        IShareToken debtShareToken;
        uint256 protectedShareBalance;
        uint256 collateralShareBalance;
        uint256 debtShareBalance;
        uint256 totalCollateralAssets;
        uint256 debtAssets;
        ISiloOracle collateralOracle;
        address collateralToken;
        uint256 maxLtv;
        ISiloOracle debtOracle;
        address debtToken;
        uint256 collateralValue;
        uint256 maxDebtValue;
        uint256 debtValue;
    }

    // solhint-disable-next-line code-complexity
    function maxBorrow(
        ISiloConfig _config,
        address _borrower,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 maxAssets, uint256 maxShares) {
        (ISiloConfig.ConfigData memory configData, address asset) = _config.getConfigWithAsset(address(this));

        MaxBorrowCache memory cache;

        cache.protectedShareToken = SiloStdLib.findShareToken(configData, SiloStdLib.AssetType.Protected, asset);
        cache.collateralShareToken = SiloStdLib.findShareToken(configData, SiloStdLib.AssetType.Collateral, asset);
        cache.debtShareToken = SiloStdLib.findShareToken(configData, SiloStdLib.AssetType.Debt, asset);

        cache.protectedShareBalance = cache.protectedShareToken.balanceOf(_borrower);
        cache.collateralShareBalance = cache.collateralShareToken.balanceOf(_borrower);
        cache.debtShareBalance = cache.debtShareToken.balanceOf(_borrower);

        // no collateral, no borrow
        if (cache.protectedShareBalance + cache.collateralShareBalance == 0) return (0, 0);

        if (cache.protectedShareBalance != 0) {
            cache.totalCollateralAssets += SiloERC4626Lib.convertToAssets(
                cache.protectedShareBalance,
                _assetStorage[asset].protectedAssets,
                cache.protectedShareToken.totalSupply(),
                MathUpgradeable.Rounding.Down
            );
        }

        if (cache.collateralShareBalance != 0) {
            (uint256 totalAssets, uint256 totalShares) = SiloStdLib.getTotalAssetsAndTotalShares(
                configData, asset, SiloStdLib.AssetType.Collateral, _assetStorage
            );

            cache.totalCollateralAssets += SiloERC4626Lib.convertToAssets(
                cache.collateralShareBalance, totalAssets, totalShares, MathUpgradeable.Rounding.Down
            );
        }

        if (cache.debtShareBalance != 0) {
            (uint256 totalAssets, uint256 totalShares) =
                SiloStdLib.getTotalAssetsAndTotalShares(configData, asset, SiloStdLib.AssetType.Debt, _assetStorage);

            cache.debtAssets += SiloERC4626Lib.convertToAssets(
                cache.debtShareBalance, totalAssets, totalShares, MathUpgradeable.Rounding.Up
            );
        }

        cache.debtToken = asset;

        if (asset == configData.token0) {
            cache.collateralToken = configData.token1;
            cache.collateralOracle = ISiloOracle(configData.ltvOracle1);
            cache.maxLtv = configData.maxLtv1;

            cache.debtOracle = ISiloOracle(configData.ltvOracle0);
        } else {
            cache.collateralToken = configData.token0;
            cache.collateralOracle = ISiloOracle(configData.ltvOracle0);
            cache.maxLtv = configData.maxLtv0;

            cache.debtOracle = ISiloOracle(configData.ltvOracle1);
        }

        // if no oracle is set, assume price 1
        cache.collateralValue = address(cache.collateralOracle) != address(0)
            ? cache.collateralOracle.quoteView(cache.totalCollateralAssets, cache.collateralToken)
            : cache.totalCollateralAssets;

        cache.maxDebtValue = cache.collateralValue * cache.maxLtv / _PRECISION_DECIMALS;

        cache.debtValue = address(cache.debtOracle) != address(0)
            ? cache.debtOracle.quoteView(cache.debtAssets, cache.debtToken)
            : cache.debtAssets;

        // if LTV is higher than maxLTV, user cannot borrow more
        if (cache.debtValue >= cache.maxDebtValue) return (0, 0);

        maxAssets = cache.debtAssets * cache.maxDebtValue / cache.debtValue - cache.debtAssets;
        maxShares = SiloERC4626Lib.convertToShares(
            maxAssets, cache.debtAssets, cache.debtShareToken.totalSupply(), MathUpgradeable.Rounding.Down
        );
    }

    function previewBorrow(
        ISiloConfig _config,
        uint256 _assets,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 shares) {
        (ISiloConfig.ConfigData memory configData, address asset) = _config.getConfigWithAsset(address(this));

        (uint256 totalAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalShares(configData, asset, SiloStdLib.AssetType.Debt, _assetStorage);

        return SiloERC4626Lib.convertToShares(_assets, totalAssets, totalShares, MathUpgradeable.Rounding.Up);
    }

    struct BorrowCache {
        IShareToken debtShareToken;
        uint256 totalDebtAssets;
        uint256 totalDebtShares;
        uint256 ltv;
        bool isToken0Collateral;
        uint256 maxLtv;
    }

    function borrow(
        ISiloConfig.ConfigData memory _configData,
        address _asset,
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        address _borrower,
        address _spender,
        ISilo.UseAssets _isAssets,
        ISilo.CheckSolvency _checkSolvency,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 assets, uint256 shares) {
        if (!borrowPossible(_configData, _asset, _borrower)) revert ISilo.BorrowNotPossible();

        accrueInterest(_configData, _asset, _assetStorage);

        BorrowCache memory cache;

        cache.debtShareToken = SiloStdLib.findShareToken(_configData, SiloStdLib.AssetType.Debt, _asset);
        cache.totalDebtAssets = _assetStorage[_asset].debtAssets;
        cache.totalDebtShares = cache.debtShareToken.totalSupply();

        if (_isAssets == ISilo.UseAssets.Yes) {
            // borrowing assets
            shares = SiloERC4626Lib.convertToShares(
                _assets, cache.totalDebtAssets, cache.totalDebtShares, MathUpgradeable.Rounding.Up
            );
            assets = _assets;
        } else {
            // borrowing shares
            shares = _shares;
            assets = SiloERC4626Lib.convertToAssets(
                _shares, cache.totalDebtAssets, cache.totalDebtShares, MathUpgradeable.Rounding.Down
            );
        }

        if (assets > SiloStdLib.liquidity(_asset, _assetStorage)) revert ISilo.NotEnoughLiquidity();

        /// @dev add new debt
        _assetStorage[_asset].debtAssets += assets;
        /// @dev `mint` checks if _spender is allowed to borrow on the account of _borrower. Hook receiver can
        ///      potentially reenter but the state is correct.
        cache.debtShareToken.mint(_borrower, _spender, shares);
        /// @dev fee-on-transfer is ignored. If token reenters, state is already finilized, no harm done.
        IERC20Upgradeable(_asset).safeTransferFrom(address(this), _receiver, assets);

        /// @dev during leverage allow for solvency check after a callback is called to allow for collateral deposit
        if (_checkSolvency == ISilo.CheckSolvency.Yes) {
            /// @dev `_borrower` must be below maxLtv
            (cache.ltv, cache.isToken0Collateral) = SiloSolvencyLib.getLtv(_configData, _borrower);
            cache.maxLtv = cache.isToken0Collateral ? _configData.maxLtv0 : _configData.maxLtv1;

            if (cache.ltv > cache.maxLtv) revert ISilo.NotSolvent();
        }
    }

    function previewBorrowShares(
        ISiloConfig _config,
        uint256 _shares,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 assets) {
        (ISiloConfig.ConfigData memory configData, address asset) = _config.getConfigWithAsset(address(this));

        (uint256 totalAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalShares(configData, asset, SiloStdLib.AssetType.Debt, _assetStorage);

        return SiloERC4626Lib.convertToAssets(_shares, totalAssets, totalShares, MathUpgradeable.Rounding.Down);
    }

    function maxRepay(
        ISiloConfig _config,
        address _borrower,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 assets, uint256 shares) {
        (ISiloConfig.ConfigData memory configData, address asset) = _config.getConfigWithAsset(address(this));

        IShareToken debtShareToken = SiloStdLib.findShareToken(configData, SiloStdLib.AssetType.Debt, asset);
        shares = debtShareToken.balanceOf(_borrower);

        (uint256 totalAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalShares(configData, asset, SiloStdLib.AssetType.Debt, _assetStorage);

        assets = SiloERC4626Lib.convertToAssets(shares, totalAssets, totalShares, MathUpgradeable.Rounding.Up);
    }

    function previewRepay(
        ISiloConfig _config,
        uint256 _assets,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 shares) {
        (ISiloConfig.ConfigData memory configData, address asset) = _config.getConfigWithAsset(address(this));

        (uint256 totalAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalShares(configData, asset, SiloStdLib.AssetType.Debt, _assetStorage);

        return SiloERC4626Lib.convertToShares(_assets, totalAssets, totalShares, MathUpgradeable.Rounding.Down);
    }

    function repay(
        ISiloConfig _config,
        uint256 _assets,
        uint256 _shares,
        address _borrower,
        address _repayer,
        ISilo.UseAssets _isAssets,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 assets, uint256 shares) {
        (ISiloConfig.SmallConfigData memory smallConfigData, address asset) =
            _config.getSmallConfigWithAsset(address(this));
        ISiloConfig.ConfigData memory configData = smallConfigToConfig(smallConfigData);

        accrueInterest(configData, asset, _assetStorage);

        IShareToken debtShareToken = SiloStdLib.findShareToken(configData, SiloStdLib.AssetType.Debt, asset);
        uint256 totalDebtAmount = _assetStorage[asset].debtAssets;
        uint256 totalDebtShares = debtShareToken.totalSupply();
        uint256 shareDebtBalance = debtShareToken.balanceOf(_borrower);

        if (_isAssets == ISilo.UseAssets.Yes) {
            // repaying assets
            shares = SiloERC4626Lib.convertToShares(
                _assets, totalDebtAmount, totalDebtShares, MathUpgradeable.Rounding.Down
            );
            assets = _assets;
        } else {
            // repaying shares
            shares = _shares;
            assets =
                SiloERC4626Lib.convertToAssets(_shares, totalDebtAmount, totalDebtShares, MathUpgradeable.Rounding.Up);
        }

        // repay max if shares above balance
        if (shares > shareDebtBalance) {
            shares = shareDebtBalance;
            assets =
                SiloERC4626Lib.convertToAssets(shares, totalDebtAmount, totalDebtShares, MathUpgradeable.Rounding.Up);
        }

        /// @dev fee-on-transfer is ignored
        ///      If token reenters, no harm done because we didn't change the state yet.
        IERC20Upgradeable(asset).safeTransferFrom(_repayer, address(this), assets);
        /// @dev subtract repayment from debt
        _assetStorage[asset].debtAssets -= assets;
        /// @dev anyone can repay anyone's debt so no approval check is needed. If hook receiver reenters then
        ///      no harm done because state changes are completed.
        debtShareToken.burn(_borrower, _repayer, shares);
    }

    function previewRepayShares(
        ISiloConfig _config,
        uint256 _shares,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 assets) {
        (ISiloConfig.ConfigData memory configData, address asset) = _config.getConfigWithAsset(address(this));

        (uint256 totalAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalShares(configData, asset, SiloStdLib.AssetType.Debt, _assetStorage);

        assets = SiloERC4626Lib.convertToAssets(_shares, totalAssets, totalShares, MathUpgradeable.Rounding.Up);
    }

    struct AccrueInterestCache {
        uint256 lastTimestamp;
        IInterestRateModel model;
        uint256 rcomp;
        uint256 totalFee;
        uint256 collateralAssets;
        uint256 debtAssets;
        uint256 daoAndDeployerAmount;
        uint256 depositorsAmount;
        uint256 daoAndDeployerShare;
    }

    function accrueInterest(
        ISiloConfig.ConfigData memory _configData,
        address _asset,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 accruedInterest) {
        AccrueInterestCache memory cache;

        cache.lastTimestamp = _assetStorage[_asset].interestRateTimestamp;

        // This is the first time, so we can return early and save some gas
        if (cache.lastTimestamp == 0) {
            _assetStorage[_asset].interestRateTimestamp = uint64(block.timestamp);
            return 0;
        }

        // Interest has already been accrued this block
        if (cache.lastTimestamp == block.timestamp) {
            return 0;
        }

        cache.model = IInterestRateModel(SiloStdLib.findModel(_configData, _asset));

        cache.rcomp = cache.model.getCompoundInterestRateAndUpdate(_asset, block.timestamp);
        cache.totalFee = _configData.daoFee + _configData.deployerFee;

        cache.collateralAssets = _assetStorage[_asset].collateralAssets;
        cache.debtAssets = _assetStorage[_asset].debtAssets;

        accruedInterest = cache.debtAssets * cache.rcomp / _PRECISION_DECIMALS;

        unchecked {
            // If we overflow on multiplication it should not revert tx, we will get lower fees
            cache.daoAndDeployerAmount = accruedInterest * cache.totalFee / _PRECISION_DECIMALS;
            cache.depositorsAmount = accruedInterest - cache.daoAndDeployerAmount;
        }

        // update contract state
        _assetStorage[_asset].debtAssets = cache.debtAssets + accruedInterest;
        _assetStorage[_asset].collateralAssets = cache.collateralAssets + cache.depositorsAmount;
        _assetStorage[_asset].interestRateTimestamp = uint64(block.timestamp);
        _assetStorage[_asset].daoAndDeployerFees += cache.daoAndDeployerAmount;
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
