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

    struct MoveCollateralShares {
        address shareTokenFrom;
        address shareTokenTo;
        uint256 shares;
        address spender;
        address receiver;
    }

    uint256 internal constant _PRECISION_DECIMALS = 1e18;
    uint256 internal constant _BASIS_POINTS = 1e4;

    function borrow(
        ISiloConfig.ConfigData memory _configData,
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        address _borrower,
        address _spender,
        ISilo.Assets storage _totalDebt,
        uint256 _totalCollateral
    ) internal returns (uint256 assets, uint256 shares) {
        BorrowCache memory cache;

        cache.debtShareToken = IShareToken(_configData.debtShareToken);
        cache.totalDebtAssets = _totalDebt.assets;
        cache.totalDebtShares = cache.debtShareToken.totalSupply();

        if (_assets == 0) {
            // borrowing shares
            shares = _shares;
            assets = SiloERC4626Lib.convertToAssets(
                _shares, cache.totalDebtAssets, cache.totalDebtShares, MathUpgradeable.Rounding.Down
            );
        } else {
            // borrowing assets
            shares = SiloERC4626Lib.convertToShares(
                _assets, cache.totalDebtAssets, cache.totalDebtShares, MathUpgradeable.Rounding.Up
            );
            assets = _assets;
        }

        if (assets > SiloStdLib.liquidity(_totalCollateral, cache.totalDebtAssets)) revert ISilo.NotEnoughLiquidity();

        // add new debt
        _totalDebt.assets += assets;
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
        ISilo.Assets storage _totalDebt
    ) internal returns (uint256 assets, uint256 shares) {
        RepayCache memory cache;

        cache.debtShareToken = IShareToken(_configData.debtShareToken);
        cache.totalDebtAmount = _totalDebt.assets;
        cache.totalDebtShares = cache.debtShareToken.totalSupply();
        cache.shareDebtBalance = cache.debtShareToken.balanceOf(_borrower);

        if (_assets == 0) {
            // repaying shares
            shares = _shares;
            assets = SiloERC4626Lib.convertToAssets(
                _shares, cache.totalDebtAmount, cache.totalDebtShares, MathUpgradeable.Rounding.Up
            );
        } else {
            // repaying assets
            shares = SiloERC4626Lib.convertToShares(
                _assets, cache.totalDebtAmount, cache.totalDebtShares, MathUpgradeable.Rounding.Down
            );
            assets = _assets;
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
        _totalDebt.assets -= assets;
        // Anyone can repay anyone's debt so no approval check is needed. If hook receiver reenters then
        // no harm done because state changes are completed.
        cache.debtShareToken.burn(_borrower, _repayer, shares);
    }

    /// @dev this method will accrue interest for ONE asset ONLY, to calculate all you have to call it twice
    /// with `_configData` for each token
    function accrueInterestForAsset(
        ISiloConfig.ConfigData memory _assetConfig,
        ISilo.SiloData storage _siloData,
        ISilo.Assets storage _totalCollateral,
        ISilo.Assets storage _totalDebt
    ) internal returns (uint256 accruedInterest) {
        AccrueInterestCache memory cache;

        cache.lastTimestamp = _siloData.interestRateTimestamp;

        // This is the first time, so we can return early and save some gas
        if (cache.lastTimestamp == 0) {
            _siloData.interestRateTimestamp = uint64(block.timestamp);
            return 0;
        }

        // Interest has already been accrued this block
        if (cache.lastTimestamp == block.timestamp) {
            return 0;
        }

        cache.rcomp = IInterestRateModel(_assetConfig.interestRateModel).getCompoundInterestRateAndUpdate(
            block.timestamp
        );
        cache.totalFeeInBp = _assetConfig.daoFeeInBp + _assetConfig.deployerFeeInBp;

        cache.collateralAssets = _totalCollateral.assets;
        cache.debtAssets = _totalDebt.assets;

        accruedInterest = cache.debtAssets * cache.rcomp / _PRECISION_DECIMALS;

        unchecked {
            // If we overflow on multiplication it should not revert tx, we will get lower fees
            cache.daoAndDeployerAmount = accruedInterest * cache.totalFeeInBp / _BASIS_POINTS;
            cache.depositorsAmount = accruedInterest - cache.daoAndDeployerAmount;
        }

        // update contract state
        _totalDebt.assets = cache.debtAssets + accruedInterest;
        _totalCollateral.assets = cache.collateralAssets + cache.depositorsAmount;
        _siloData.interestRateTimestamp = uint64(block.timestamp);
        _siloData.daoAndDeployerFees += cache.daoAndDeployerAmount;
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
        uint256 _totalDebtAssets
    ) internal view returns (uint256 assets, uint256 shares) {
        (ISiloConfig.ConfigData memory debtConfig, ISiloConfig.ConfigData memory collateralConfig) =
            _config.getConfigs(address(this));

        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.getAssetsDataForLtvCalculations(
            collateralConfig, debtConfig, _borrower, ISilo.OracleType.MaxLtv, ISilo.AccrueInterestInMemory.Yes
        );

        (
            uint256 collateralValue, uint256 debtValue
        ) = SiloSolvencyLib.getPositionValues(ltvData, debtConfig.token, collateralConfig.token);

        uint256 ltv = debtValue * _PRECISION_DECIMALS / collateralValue;

        // if LTV is higher than maxLTV, user cannot borrow more
        if (ltv >= collateralConfig.maxLtv) return (0, 0);

        {
            uint256 maxDebtValue = collateralValue * collateralConfig.maxLtv / _PRECISION_DECIMALS;
            IShareToken debtShareToken = IShareToken(debtConfig.debtShareToken);
            uint256 debtShareBalance = debtShareToken.balanceOf(_borrower);
            shares = debtShareBalance * maxDebtValue / debtValue - debtShareBalance;
        }

        {
            (uint256 totalAssets, uint256 totalShares) = SiloStdLib.getTotalAssetsAndTotalShares(
                debtConfig, ISilo.AssetType.Debt, _totalDebtAssets
            );

            assets = SiloERC4626Lib.convertToAssets(shares, totalAssets, totalShares, MathUpgradeable.Rounding.Up);
        }
    }

    function maxRepay(
        ISiloConfig _config,
        address _borrower,
        uint256 _totalDebtAssets
    ) internal view returns (uint256 assets, uint256 shares) {
        ISiloConfig.ConfigData memory configData = _config.getConfig(address(this));

        shares = IShareToken(configData.debtShareToken).balanceOf(_borrower);

        assets = SiloERC4626Lib.convertToAssetsOrToShares(
            _config,
            shares,
            ISilo.AssetType.Debt,
            SiloERC4626Lib.convertToAssets,
            MathUpgradeable.Rounding.Up,
            _totalDebtAssets
        );
    }
}
