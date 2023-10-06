// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {MathUpgradeable} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

library SiloMathLib {
    using MathUpgradeable for uint256;

    uint256 internal constant _PRECISION_DECIMALS = 1e18;
    uint256 internal constant _BASIS_POINTS = 1e4;

    /// @dev this is constant version of openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626._decimalsOffset
    uint256 internal constant _DECIMALS_OFFSET_POW = 10 ** 0;

    /// @notice Returns available liquidity to be borrowed
    /// @dev Accrued interest is entirely added to `debtAssets` but only part of it is added to `collateralAssets`. The
    ///      difference is DAO's and deployer's cut. That means DAO's and deployer's cut is not considered a borrowable
    ///      liquidity.
    function liquidity(uint256 _collateralAssets, uint256 _debtAssets) internal pure returns (uint256 liquidAssets) {
        unchecked {
            // we checked the underflow
            liquidAssets = _debtAssets > _collateralAssets ? 0 : _collateralAssets - _debtAssets;
        }
    }

    function getCollateralAmountsWithInterest(
        uint256 _collateralAssets,
        uint256 _debtAssets,
        uint256 _rcompInDp,
        uint256 _daoFeeInBp,
        uint256 _deployerFeeInBp
    )
        internal
        pure
        returns (
            uint256 collateralAssetsWithInterest,
            uint256 debtAssetsWithInterest,
            uint256 daoAndDeployerFees,
            uint256 accruedInterest
        )
    {
        (debtAssetsWithInterest, accruedInterest) = getDebtAmountsWithInterest(_debtAssets, _rcompInDp);
        uint256 collateralInterest;

        unchecked {
            // If we overflow on multiplication it should not revert tx, we will get lower fees
            daoAndDeployerFees = accruedInterest * (_daoFeeInBp + _deployerFeeInBp) / _BASIS_POINTS;
            // we will not underflow because daoAndDeployerFees is chunk of accruedInterest
            collateralInterest = accruedInterest - daoAndDeployerFees;
        }

        collateralAssetsWithInterest = _collateralAssets + collateralInterest;
    }

    function getDebtAmountsWithInterest(uint256 _debtAssets, uint256 _rcompInDp)
        internal
        pure
        returns (uint256 debtAssetsWithInterest, uint256 accruedInterest)
    {
        if (_debtAssets == 0 || _rcompInDp == 0) {
            return (_debtAssets, 0);
        }

        unchecked {
            // If we overflow on multiplication it should not revert tx, we will get lower fees
            accruedInterest = _debtAssets * _rcompInDp / _PRECISION_DECIMALS;
        }

        debtAssetsWithInterest = _debtAssets + accruedInterest;
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

    function convertToAssetsAndToShares(
        uint256 _assets,
        uint256 _shares,
        uint256 _totalAssets,
        uint256 _totalShares,
        MathUpgradeable.Rounding _roundingToAssets,
        MathUpgradeable.Rounding _roundingToShares,
        ISilo.AssetType _assetType
    ) internal pure returns (uint256 assets, uint256 shares) {
        if (_assets == 0) {
            shares = _shares;
            assets = convertToAssets(_shares, _totalAssets, _totalShares, _roundingToAssets, _assetType);
        } else {
            shares = convertToShares(_assets, _totalAssets, _totalShares, _roundingToShares, _assetType);
            assets = _assets;
        }
    }

    /// @dev Math for collateral is exact copy of
    ///      openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626._convertToShares
    function convertToShares(
        uint256 _assets,
        uint256 _totalAssets,
        uint256 _totalShares,
        MathUpgradeable.Rounding _rounding,
        ISilo.AssetType _assetType
    ) internal pure returns (uint256) {
        // Debt calculations should not lower the result. Debt is a liability so protocol should not take any for
        // itself. It should return actual result and round it up.
        (uint256 offsetPow, uint256 one) = _assetType == ISilo.AssetType.Debt ? (0, 0) : (_DECIMALS_OFFSET_POW, 1);

        if (_totalShares + offsetPow == 0 || _totalAssets + one == 0) return _assets;

        return _assets.mulDiv(_totalShares + offsetPow, _totalAssets + one, _rounding);
    }

    /// @dev Math for collateral is exact copy of
    ///      openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626._convertToAssets
    function convertToAssets(
        uint256 _shares,
        uint256 _totalAssets,
        uint256 _totalShares,
        MathUpgradeable.Rounding _rounding,
        ISilo.AssetType _assetType
    ) internal pure returns (uint256 assets) {
        // Debt calculations should not lower the result. Debt is a liability so protocol should not take any for
        // itself. It should return actual result and round it up.
        (uint256 offsetPow, uint256 one) = _assetType == ISilo.AssetType.Debt ? (0, 0) : (_DECIMALS_OFFSET_POW, 1);

        if (_totalShares + offsetPow == 0 || _totalAssets + one == 0) return _shares;

        assets = _shares.mulDiv(_totalAssets + one, _totalShares + offsetPow, _rounding);
    }

    /// @return maxBorrowValue max borrow value yet available for borrower
    function calculateMaxBorrowValue(
        uint256 _configMaxLtvInBp,
        uint256 _sumOfBorrowerCollateralValue,
        uint256 _borrowerDebtValue
    ) internal pure returns (uint256 maxBorrowValue) {
        if (_sumOfBorrowerCollateralValue == 0) {
            return 0;
        }

        uint256 maxDebtValue = _sumOfBorrowerCollateralValue * _configMaxLtvInBp / _BASIS_POINTS;

        unchecked {
            // we will not underflow because we checking `maxDebtValue > _borrowerDebtValue`
            maxBorrowValue = maxDebtValue > _borrowerDebtValue ? maxDebtValue - _borrowerDebtValue : 0;
        }
    }

    function calculateMaxAssetsToWithdraw(
        uint256 _sumOfCollateralsValue,
        uint256 _debtValue,
        uint256 _ltInBp,
        uint256 _borrowerCollateralAssets,
        uint256 _borrowerProtectedAssets
    ) internal pure returns (uint256 maxAssets) {
        if (_sumOfCollateralsValue == 0) return 0;
        if (_debtValue == 0) return _sumOfCollateralsValue;
        if (_ltInBp == 0) return 0;

        uint256 minimumCollateralValue = _debtValue * _BASIS_POINTS;
        unchecked { minimumCollateralValue /= _ltInBp; }

        // if we over LT, we can not withdraw
        if (_sumOfCollateralsValue <= minimumCollateralValue) {
            return 0;
        }

        uint256 spareCollateralValue;
        // safe because we checked `if (_sumOfCollateralsValue <= minimumCollateralValue)`
        unchecked { spareCollateralValue = _sumOfCollateralsValue - minimumCollateralValue; }

        unchecked {
            // these are total assets (protected + collateral) that _owner can withdraw
            // + is safe because we adding same asset (under sme total supply)
            // * can potentially overflow, but it is unlikely, we would overflow in LTV calculations first
            // worse what can happen we return lower number than real MAX on overflow
            maxAssets = (_borrowerProtectedAssets + _borrowerCollateralAssets) * spareCollateralValue
                / _sumOfCollateralsValue;
        }
    }

    /// @param _maxAssets result of calculateMaxAssetsToWithdraw()
    /// @param _assetTypeShareTokenTotalSupply depends on `_assetType`: protected or collateral share token total supply
    function maxWithdrawToAssetsAndShares(
        uint256 _maxAssets,
        uint256 _borrowerCollateralAssets,
        uint256 _borrowerProtectedAssets,
        ISilo.AssetType _assetType,
        uint256 _totalAssets,
        uint256 _assetTypeShareTokenTotalSupply,
        uint256 _liquidity
    ) internal pure returns (uint256 assets, uint256 shares) {
        if (_maxAssets == 0) return (0, 0);
        if (_assetTypeShareTokenTotalSupply == 0) return (0, 0);

        if (_assetType == ISilo.AssetType.Protected) {
            assets = _maxAssets > _borrowerProtectedAssets ? _borrowerProtectedAssets : _maxAssets;
        } else if (_assetType == ISilo.AssetType.Collateral) {
            assets = _maxAssets > _borrowerCollateralAssets ? _borrowerCollateralAssets : _maxAssets;

            if (assets > _liquidity) {
                assets = _liquidity;
            }
        }

        shares = SiloMathLib.convertToShares(
            assets,
            _totalAssets,
            _assetTypeShareTokenTotalSupply,
            MathUpgradeable.Rounding.Down,
            _assetType
        );
    }
}
