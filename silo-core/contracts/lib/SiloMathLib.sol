// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Math} from "openzeppelin5/utils/math/Math.sol";
import {Rounding} from "../lib/Rounding.sol";
import {ISilo} from "../interfaces/ISilo.sol";

library SiloMathLib {
    using Math for uint256;

    uint256 internal constant _PRECISION_DECIMALS = 1e18;

    /// @dev this is constant version of openzeppelin5/contracts/token/ERC20/extensions/ERC4626._decimalsOffset
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

    /// @notice Calculate collateral assets with accrued interest and associated fees
    /// @param _collateralAssets The total amount of collateral assets
    /// @param _debtAssets The total amount of debt assets
    /// @param _rcomp Compound interest rate for debt
    /// @param _daoFee The fee (in 18 decimals points) to be taken for the DAO
    /// @param _deployerFee The fee (in 18 decimals points) to be taken for the deployer
    /// @return collateralAssetsWithInterest The total collateral assets including the accrued interest
    /// @return debtAssetsWithInterest The debt assets with accrued interest
    /// @return daoAndDeployerRevenue Total fees amount to be split between DAO and deployer
    /// @return accruedInterest The total accrued interest
    function getCollateralAmountsWithInterest(
        uint256 _collateralAssets,
        uint256 _debtAssets,
        uint256 _rcomp,
        uint256 _daoFee,
        uint256 _deployerFee
    )
        internal
        pure
        returns (
            uint256 collateralAssetsWithInterest,
            uint256 debtAssetsWithInterest,
            uint256 daoAndDeployerRevenue,
            uint256 accruedInterest
        )
    {
        (debtAssetsWithInterest, accruedInterest) = getDebtAmountsWithInterest(_debtAssets, _rcomp);
        uint256 collateralInterest;

        unchecked {
            // If we overflow on multiplication it should not revert tx, we will get lower fees
            daoAndDeployerRevenue = accruedInterest * (_daoFee + _deployerFee) / _PRECISION_DECIMALS;
            // we will not underflow because daoAndDeployerRevenue is chunk of accruedInterest
            // even when we overflow on above *, daoAndDeployerRevenue will be even lower chunk
            collateralInterest = accruedInterest - daoAndDeployerRevenue;

            // save to uncheck because variable can not be more than max
            uint256 cap = type(uint256).max - _collateralAssets;

            // TODO if we cap interest on debt and now we cap on collateral - can it have impact on something?
            // eg. is it possible to generate more debt so then we can not withdraw collateral because we short with tokens?
            // scenario: collateral is 70%max, debt is 50%max, interest 40%max
            // but on collateral it will be cap to 30%max (because 70% + 40% will give overflow).
            // what happen with 10% diff??
            if (cap < collateralInterest) {
                collateralInterest = cap;
            }

            // safe to uncheck because of cap
            collateralAssetsWithInterest = _collateralAssets + collateralInterest;
        }
    }

    /// @notice Calculate the debt assets with accrued interest, it should never revert with over/under flow
    /// @param _totalDebtAssets The total amount of debt assets before accrued interest
    /// @param _rcomp Compound interest rate for the debt in 18 decimal precision
    /// @return debtAssetsWithInterest The debt assets including the accrued interest
    /// @return accruedInterest The total amount of interest accrued on the debt assets
    function getDebtAmountsWithInterest(uint256 _totalDebtAssets, uint256 _rcomp)
        internal
        pure
        returns (uint256 debtAssetsWithInterest, uint256 accruedInterest)
    {
        if (_totalDebtAssets == 0 || _rcomp == 0) {
            return (_totalDebtAssets, 0);
        }

        unchecked {
            /*
            how to prevent overflow on: _totalDebtAssets.mulDiv(_rcomp, _PRECISION_DECIMALS, Rounding.ACCRUED_INTEREST):
            1. max > _totalDebtAssets * _rcomp / _PRECISION_DECIMALS
            2. max / _rcomp > _totalDebtAssets / _PRECISION_DECIMALS
            */
            // save to unchecked because we only have division and `_rcomp` is not 0 based on above check
            if (type(uint256).max / _rcomp > _totalDebtAssets / _PRECISION_DECIMALS) {
                accruedInterest = _totalDebtAssets.mulDiv(_rcomp, _PRECISION_DECIMALS, Rounding.ACCRUED_INTEREST);
            } else {
                // we have overflow on accruedInterest
                accruedInterest = type(uint256).max;
            }

            // save to uncheck because variable `_totalDebtAssets` can not be more than type.max
            uint256 cap = type(uint256).max - _totalDebtAssets;

            if (accruedInterest > cap) {
                // overflow on interest
                accruedInterest = cap;
            }

            debtAssetsWithInterest = _totalDebtAssets + accruedInterest;
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

    function convertToAssetsAndToShares(
        uint256 _assets,
        uint256 _shares,
        uint256 _totalAssets,
        uint256 _totalShares,
        Math.Rounding _roundingToAssets,
        Math.Rounding _roundingToShares,
        ISilo.AssetType _assetType
    ) internal pure returns (uint256 assets, uint256 shares) {
        if (_assets == 0) {
            shares = _shares;
            assets = convertToAssets(_shares, _totalAssets, _totalShares, _roundingToAssets, _assetType);
        } else if (_shares == 0) {
            shares = convertToShares(_assets, _totalAssets, _totalShares, _roundingToShares, _assetType);
            assets = _assets;
        } else {
            revert ISilo.InputCanBeAssetsOrShares();
        }
    }

    /// @dev Math for collateral is exact copy of
    ///      openzeppelin5/contracts/token/ERC20/extensions/ERC4626._convertToShares
    function convertToShares(
        uint256 _assets,
        uint256 _totalAssets,
        uint256 _totalShares,
        Math.Rounding _rounding,
        ISilo.AssetType _assetType
    ) internal pure returns (uint256) {
        (uint256 totalShares, uint256 totalAssets) = _commonConvertTo(_totalAssets, _totalShares, _assetType);

        // initially, in case of debt, if silo is empty we return shares==assets
        // for collateral, this will never be the case, because of `+1` in line above
        if (totalShares == 0) return _assets;

        return _assets.mulDiv(totalShares, totalAssets, _rounding);
    }

    /// @dev Math for collateral is exact copy of
    ///      openzeppelin5/contracts/token/ERC20/extensions/ERC4626._convertToAssets
    function convertToAssets(
        uint256 _shares,
        uint256 _totalAssets,
        uint256 _totalShares,
        Math.Rounding _rounding,
        ISilo.AssetType _assetType
    ) internal pure returns (uint256 assets) {
        (uint256 totalShares, uint256 totalAssets) = _commonConvertTo(_totalAssets, _totalShares, _assetType);

        // initially, in case of debt, if silo is empty we return shares==assets
        // for collateral, this will never be the case, because of `+1` in line above
        if (totalShares == 0) return _shares;

        assets = _shares.mulDiv(totalAssets, totalShares, _rounding);
    }

    /// @return maxBorrowValue max borrow value yet available for borrower
    function calculateMaxBorrowValue(
        uint256 _configMaxLtv,
        uint256 _sumOfBorrowerCollateralValue,
        uint256 _borrowerDebtValue
    ) internal pure returns (uint256 maxBorrowValue) {
        if (_sumOfBorrowerCollateralValue == 0) {
            return 0;
        }

        uint256 maxDebtValue = _sumOfBorrowerCollateralValue.mulDiv(
            _configMaxLtv, _PRECISION_DECIMALS, Rounding.MAX_BORROW_VALUE
        );

        unchecked {
            // we will not underflow because we checking `maxDebtValue > _borrowerDebtValue`
            maxBorrowValue = maxDebtValue > _borrowerDebtValue ? maxDebtValue - _borrowerDebtValue : 0;
        }
    }

    /// @notice Calculate the maximum assets a borrower can withdraw without breaching the liquidation threshold
    /// @param _sumOfCollateralsValue The combined value of collateral and protected assets of the borrower
    /// @param _debtValue The total debt value of the borrower
    /// @param _lt The liquidation threshold in 18 decimal points
    /// @param _borrowerCollateralAssets The borrower's collateral assets before the withdrawal
    /// @param _borrowerProtectedAssets The borrower's protected assets before the withdrawal
    /// @return maxAssets The maximum assets the borrower can safely withdraw
    function calculateMaxAssetsToWithdraw(
        uint256 _sumOfCollateralsValue,
        uint256 _debtValue,
        uint256 _lt,
        uint256 _borrowerCollateralAssets,
        uint256 _borrowerProtectedAssets
    ) internal pure returns (uint256 maxAssets) {
        if (_sumOfCollateralsValue == 0) return 0;
        if (_debtValue == 0) return _sumOfCollateralsValue;
        if (_lt == 0) return 0;

        // using Rounding.LT (up) to have highest collateralValue that we have to leave for user to stay solvent
        uint256 minimumCollateralValue = _debtValue.mulDiv(_PRECISION_DECIMALS, _lt, Rounding.LTV);

        // +1 is solution for precision error that math can produce and when that happen,
        // `maxAssets` can cause insolvency, so it can not be withdraw
        // this 1 is a dust that we generating by rounding always in favor of protocol
        // potentially we could also do `maxAssets--` at the end, but adjusting value is "stronger", it will produce
        // lower assets, so it should be safer when we calculate solvency back from assets via it's value.
        // +1 will not overflow because we just divided a number by `_lt`
        unchecked { minimumCollateralValue++; }

        // if we over LT, we can not withdraw
        if (_sumOfCollateralsValue <= minimumCollateralValue) {
            return 0;
        }

        uint256 spareCollateralValue;
        // safe because we checked `if (_sumOfCollateralsValue <= minimumCollateralValue)`
        unchecked { spareCollateralValue = _sumOfCollateralsValue - minimumCollateralValue; }

        unchecked {
            // these are total assets (protected + collateral) that _owner can withdraw
            // - is safe because we adding same asset (under same total supply)
            maxAssets = (_borrowerProtectedAssets + _borrowerCollateralAssets)
                .mulDiv(spareCollateralValue, _sumOfCollateralsValue, Rounding.MAX_WITHDRAW_TO_ASSETS);
        }
    }

    /// @notice Determines the maximum number of assets and corresponding shares a borrower can safely withdraw
    /// @param _maxAssets The calculated limit on how many assets can be withdrawn without breaching the liquidation
    /// threshold
    /// @param _borrowerCollateralAssets Amount of collateral assets currently held by the borrower
    /// @param _borrowerProtectedAssets Amount of protected assets currently held by the borrower
    /// @param _collateralType Specifies whether the asset is of type Collateral or Protected
    /// @param _totalAssets The entire quantity of assets available in the system for withdrawal
    /// @param _assetTypeShareTokenTotalSupply Total supply of share tokens for the specified asset type
    /// @param _liquidity Current liquidity in the system for the asset type
    /// @return assets Maximum assets the borrower can withdraw
    /// @return shares Corresponding number of shares for the derived `assets` amount
    function maxWithdrawToAssetsAndShares(
        uint256 _maxAssets,
        uint256 _borrowerCollateralAssets,
        uint256 _borrowerProtectedAssets,
        ISilo.CollateralType _collateralType,
        uint256 _totalAssets,
        uint256 _assetTypeShareTokenTotalSupply,
        uint256 _liquidity
    ) internal pure returns (uint256 assets, uint256 shares) {
        if (_maxAssets == 0) return (0, 0);
        if (_assetTypeShareTokenTotalSupply == 0) return (0, 0);

        if (_collateralType == ISilo.CollateralType.Collateral) {
            assets = _maxAssets > _borrowerCollateralAssets ? _borrowerCollateralAssets : _maxAssets;

            if (assets > _liquidity) {
                assets = _liquidity;
            }
        } else {
            assets = _maxAssets > _borrowerProtectedAssets ? _borrowerProtectedAssets : _maxAssets;
        }

        shares = SiloMathLib.convertToShares(
            assets,
            _totalAssets,
            _assetTypeShareTokenTotalSupply,
            Rounding.MAX_WITHDRAW_TO_SHARES,
            ISilo.AssetType(uint256(_collateralType))
        );
    }

    /// @dev Debt calculations should not lower the result. Debt is a liability so protocol should not take any for
    /// itself. It should return actual result and round it up.
    function _commonConvertTo(
        uint256 _totalAssets,
        uint256 _totalShares,
        ISilo.AssetType _assetType
    ) private pure returns (uint256 totalShares, uint256 totalAssets) {
        if (_totalShares == 0) {
            // silo is empty and we have dust to redistribute: this can only happen when everyone exits silo
            // this case can happen only for collateral, because for collateral we rounding in favorite of protocol
            // by resetting totalAssets, the dust that we have will go to first depositor and we starts from clean state
            _totalAssets = 0;
        }

        unchecked {
            // I think we can afford to uncheck +1
            (totalShares, totalAssets) = _assetType == ISilo.AssetType.Debt
                ? (_totalShares, _totalAssets)
                : (_totalShares + _DECIMALS_OFFSET_POW, _totalAssets + 1);
        }
    }
}
