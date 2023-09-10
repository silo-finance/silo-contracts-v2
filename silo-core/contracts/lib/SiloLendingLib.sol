// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {SafeERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {MathUpgradeable} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";

import {ISiloOracle} from "../interfaces/ISiloOracle.sol";
import {SiloStdLib, ISiloConfig, ISilo, IShareToken, IInterestRateModel} from "./SiloStdLib.sol";
import {SiloSolvencyLib} from "./SiloSolvencyLib.sol";
import {SiloERC4626Lib} from "./SiloERC4626Lib.sol";

library SiloLendingLib {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct BorrowCache {
        IShareToken debtShareToken;
        uint256 totalDebtAssets;
        uint256 totalDebtShares;
        uint256 ltv;
        uint256 maxLtv;
    }

    struct RepayCache {
        IShareToken debtShareToken;
        uint256 totalDebtAmount;
        uint256 totalDebtShares;
        uint256 shareDebtBalance;
    }

    struct AccrueInterestCache {
        uint256 lastTimestamp;
        uint256 rcomp;
        uint256 totalFeeInBp;
        uint256 collateralAssets;
        uint256 debtAssets;
        uint256 daoAndDeployerAmount;
        uint256 depositorsAmount;
        uint256 daoAndDeployerShare;
    }

    uint256 internal constant _PRECISION_DECIMALS = 1e18;
    uint256 internal constant _BASIS_POINTS = 1e4;

    function transitionCollateral(
        ISiloConfig.ConfigData memory _configData,
        uint256 _shares,
        address _owner,
        address _spender,
        ISilo.AssetType _assetType,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 assets, uint256 shares, uint256 toShares) {
        uint256 zeroAssets = 0;
        uint256 zeroShares = 0;

        (assets, shares) = SiloERC4626Lib.withdraw(
            _configData,
            SiloERC4626Lib.WithdrawParams({
                assets: zeroAssets,
                shares: _shares,
                receiver: _owner,
                owner: _owner,
                spender: _spender,
                doTransfer: ISilo.TokenTransfer.No,
                assetType: _assetType
            }),
            ISilo.UseAssets.No,
            _assetStorage
        );

        ISilo.AssetType depositType = ISilo.AssetType((uint256(_assetType) + 1) % 2);

        (assets, toShares) = SiloERC4626Lib.deposit(
            _configData,
            _owner,
            _owner,
            assets,
            zeroShares,
            depositType,
            ISilo.UseAssets.Yes,
            ISilo.TokenTransfer.No,
            _assetStorage
        );
    }

    function borrow(
        ISiloConfig.ConfigData memory _configData,
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        address _borrower,
        address _spender,
        ISilo.UseAssets _useAssets,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 assets, uint256 shares) {
        BorrowCache memory cache;

        cache.debtShareToken = IShareToken(_configData.debtShareToken);
        cache.totalDebtAssets = _assetStorage[_configData.token].debtAssets;
        cache.totalDebtShares = cache.debtShareToken.totalSupply();

        if (_useAssets == ISilo.UseAssets.Yes) {
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

        if (assets > SiloStdLib.liquidity(_configData.token, _assetStorage)) revert ISilo.NotEnoughLiquidity();

        // add new debt
        _assetStorage[_configData.token].debtAssets += assets;
        // `mint` checks if _spender is allowed to borrow on the account of _borrower. Hook receiver can
        // potentially reenter but the state is correct.
        cache.debtShareToken.mint(_borrower, _spender, shares);
        // fee-on-transfer is ignored. If token reenters, state is already finilized, no harm done.
        IERC20Upgradeable(_configData.token).safeTransferFrom(address(this), _receiver, assets);
    }

    function repay(
        ISiloConfig.ConfigData memory _configData,
        uint256 _assets,
        uint256 _shares,
        address _borrower,
        address _repayer,
        ISilo.UseAssets _useAssets,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 assets, uint256 shares) {
        RepayCache memory cache;

        cache.debtShareToken = IShareToken(_configData.debtShareToken);
        cache.totalDebtAmount = _assetStorage[_configData.token].debtAssets;
        cache.totalDebtShares = cache.debtShareToken.totalSupply();
        cache.shareDebtBalance = cache.debtShareToken.balanceOf(_borrower);

        if (_useAssets == ISilo.UseAssets.Yes) {
            // repaying assets
            shares = SiloERC4626Lib.convertToShares(
                _assets, cache.totalDebtAmount, cache.totalDebtShares, MathUpgradeable.Rounding.Down
            );
            assets = _assets;
        } else {
            // repaying shares
            shares = _shares;
            assets = SiloERC4626Lib.convertToAssets(
                _shares, cache.totalDebtAmount, cache.totalDebtShares, MathUpgradeable.Rounding.Up
            );
        }

        // repay max if shares above balance
        if (shares > cache.shareDebtBalance) {
            shares = cache.shareDebtBalance;
            assets = SiloERC4626Lib.convertToAssets(
                shares, cache.totalDebtAmount, cache.totalDebtShares, MathUpgradeable.Rounding.Up
            );
        }

        // fee-on-transfer is ignored
        // If token reenters, no harm done because we didn't change the state yet.
        IERC20Upgradeable(_configData.token).safeTransferFrom(_repayer, address(this), assets);
        // subtract repayment from debt
        _assetStorage[_configData.token].debtAssets -= assets;
        // Anyone can repay anyone's debt so no approval check is needed. If hook receiver reenters then
        // no harm done because state changes are completed.
        cache.debtShareToken.burn(_borrower, _repayer, shares);
    }

    function accrueInterest(
        ISiloConfig.ConfigData memory _configData,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 accruedInterest) {
        AccrueInterestCache memory cache;

        cache.lastTimestamp = _assetStorage[_configData.token].interestRateTimestamp;

        // This is the first time, so we can return early and save some gas
        if (cache.lastTimestamp == 0) {
            _assetStorage[_configData.token].interestRateTimestamp = uint64(block.timestamp);
            return 0;
        }

        // Interest has already been accrued this block
        if (cache.lastTimestamp == block.timestamp) {
            return 0;
        }

        cache.rcomp = IInterestRateModel(_configData.interestRateModel).getCompoundInterestRateAndUpdate(
            _configData.token, block.timestamp
        );
        cache.totalFeeInBp = _configData.daoFee + _configData.deployerFee;

        cache.collateralAssets = _assetStorage[_configData.token].collateralAssets;
        cache.debtAssets = _assetStorage[_configData.token].debtAssets;

        accruedInterest = cache.debtAssets * cache.rcomp / _PRECISION_DECIMALS;

        unchecked {
            // If we overflow on multiplication it should not revert tx, we will get lower fees
            cache.daoAndDeployerAmount = accruedInterest * cache.totalFeeInBp / _BASIS_POINTS;
            cache.depositorsAmount = accruedInterest - cache.daoAndDeployerAmount;
        }

        // update contract state
        _assetStorage[_configData.token].debtAssets = cache.debtAssets + accruedInterest;
        _assetStorage[_configData.token].collateralAssets = cache.collateralAssets + cache.depositorsAmount;
        _assetStorage[_configData.token].interestRateTimestamp = uint64(block.timestamp);
        _assetStorage[_configData.token].daoAndDeployerFees += cache.daoAndDeployerAmount;
    }

    function borrowPossible(ISiloConfig.ConfigData memory _configData, address _borrower)
        internal
        view
        returns (bool)
    {
        uint256 totalCollateralBalance = IShareToken(_configData.protectedShareToken).balanceOf(_borrower)
            + IShareToken(_configData.collateralShareToken).balanceOf(_borrower);

        // token must be marked as borrowable and _borrower cannot have any collateral deposited
        return _configData.borrowable && totalCollateralBalance == 0;
    }

    function maxBorrow(
        ISiloConfig _config,
        address _borrower,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 assets, uint256 shares) {
        (ISiloConfig.ConfigData memory configData0, ISiloConfig.ConfigData memory configData1) =
            _config.getConfigs(address(this));

        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.getAssetsDataForLtvCalculations(
            configData0, configData1, _borrower, ISilo.OracleType.MaxLtv, ISilo.AccrueInterestInMemory.Yes
        );
        (uint256 collateralValue, uint256 debtValue) = SiloSolvencyLib.getPositionValues(ltvData);
        uint256 ltv = debtValue * _PRECISION_DECIMALS / collateralValue;

        // if LTV is higher than maxLTV, user cannot borrow more
        if (ltv >= ltvData.maxLtv) return (0, 0);

        {
            uint256 maxDebtValue = collateralValue * ltvData.maxLtv / _PRECISION_DECIMALS;
            IShareToken debtShareToken = IShareToken(configData0.debtShareToken);
            uint256 debtShareBalance = debtShareToken.balanceOf(_borrower);
            shares = debtShareBalance * maxDebtValue / debtValue - debtShareBalance;
        }

        {
            (uint256 totalAssets, uint256 totalShares) =
                SiloStdLib.getTotalAssetsAndTotalShares(configData0, ISilo.AssetType.Debt, _assetStorage);

            assets = SiloERC4626Lib.convertToAssets(shares, totalAssets, totalShares, MathUpgradeable.Rounding.Up);
        }
    }

    function maxRepay(
        ISiloConfig _config,
        address _borrower,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 assets, uint256 shares) {
        ISiloConfig.ConfigData memory configData = _config.getConfig(address(this));

        shares = IShareToken(configData.debtShareToken).balanceOf(_borrower);
        assets = SiloERC4626Lib.preview(
            _config, shares, ISilo.AssetType.Debt, ISilo.UseAssets.No, MathUpgradeable.Rounding.Up, _assetStorage
        );
    }
}
