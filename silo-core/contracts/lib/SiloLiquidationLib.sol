// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {ISiloLiquidation} from "../interfaces/ISiloLiquidation.sol";

library SiloLiquidationLib {
    uint256 internal constant _PRECISION_DECIMALS = 1e18;

    /// @dev when user is insolvent with some LT, we will allow to liquidate to: LT - LT * _TARGET_LT_LEVEL_IN_BP
    /// eg. LT=80%, _TARGET_LT_LEVEL_IN_BP=10%, then liquidation can be done to LT=72%
    uint256 internal constant _TARGET_LT_LEVEL_IN_BP = 1e4 - 1e3; // 10% => LT * (100% - 10%)

    /// @dev if repay value : total position value during liquidation is higher than _POSITION_DUST_LEVEL_IN_BP
    /// then we will force full liquidation,
    /// eg total value = 51 and dust level = 98%, then when we can not liquidate 50, we have to liquidate 51.
    uint256 internal constant _POSITION_DUST_LEVEL_IN_BP = 9000; // 90%

    /// @dev TODO check this on configuration
    function liquidateValuesVerification(
        uint256 _targetLT,
        uint256 _liquidityFee,
        uint256 _dustThreshold
    )
        internal
        pure
    {
        // 1e3 => 10% arbitrary value
        if (_liquidityFee > 1e3) revert ISiloLiquidation.LiquidityFeeToHi(); // TODO adjust
        if (_targetLT > 1e4) revert ISiloLiquidation.LiquidityLTToHi(); // TODO expect LT in 4 basis points
        if (_dustThreshold > 1e4) revert ISiloLiquidation.LiquidityLTToHi(); // TODO expect LT in 4 basis points
    }

    /// @param _debtToCover amount of debt token to use for repay
    /// @return collateralAssetsToLiquidate this is how much collateral liquidator will get
    /// @return debtAssetsToRepay this is how much debt had been repayed, it might be less or eq than `_debtToCover`
    /// @return ltvAfterLiquidation if 0, means this is full liquidation because of dust
    function calculateExactLiquidationAmounts(
        uint256 _debtToCover,
        uint256 _totalBorrowerDebtValue,
        uint256 _totalBorrowerDebtAssets,
        uint256 _totalBorrowerCollateralValue,
        uint256 _totalBorrowerCollateralAssets,
        uint256 _liquidationFee
    )
        internal
        pure
        returns (uint256 collateralAssetsToLiquidate, uint256 debtAssetsToRepay, uint256 ltvAfterLiquidation)
    {
        uint256 bp = 1e4;
        debtAssetsToRepay = _debtToCover;
        uint256 debtValueToCover = _totalBorrowerDebtValue * debtAssetsToRepay / _totalBorrowerDebtAssets;

        // do not allow dust, force full liquidation
        if (debtValueToCover * bp / _totalBorrowerDebtValue > _POSITION_DUST_LEVEL_IN_BP) {
            return (_totalBorrowerCollateralAssets, _totalBorrowerDebtAssets, 0);
        }

        uint256 collateralValueToLiquidate;

        (collateralAssetsToLiquidate, collateralValueToLiquidate) = calculateCollateral(
            debtValueToCover, _totalBorrowerCollateralValue, _totalBorrowerCollateralAssets, _liquidationFee
        );

        unchecked {
            // 1. all subs are safe because this values are chunks of total, so we will not underflow
            // 2. * is save because if we did not overflow on LTV, then target LTV will be less, so we not overflow
            ltvAfterLiquidation = (_totalBorrowerDebtValue - debtValueToCover) * _PRECISION_DECIMALS
                / (_totalBorrowerCollateralValue - collateralValueToLiquidate);
        }
    }

    /// @param _ltInBP LT liquidation threshold for asset
    /// @return minimalAcceptableLT min acceptable LT after liquidation
    function minAcceptableLT(uint256 _ltInBP) internal pure returns (uint256 minimalAcceptableLT) {
        // safe to uncheck because all values are in BP
        unchecked { minimalAcceptableLT = _ltInBP * _TARGET_LT_LEVEL_IN_BP; }
    }

    function calculateCollateral(
        uint256 _debtValueToCover,
        uint256 _totalCollateralValue,
        uint256 _totalCollateralAssets,
        uint256 _liquidationFee
    )
        internal
        pure
        returns (uint256 collateralAssets, uint256 collateralValue)
    {
        uint256 bp = 1e4; // 100%
        // TODO we can uncheck if I find math in other place that calculate this in safe way, eg interests
        collateralValue = _debtValueToCover + _debtValueToCover * _liquidationFee / bp;
        collateralAssets = collateralValue * _totalCollateralAssets;
        unchecked { collateralAssets /= _totalCollateralValue; }

        // if we do not have enough assets we need to lower the numbers
        if (collateralAssets > _totalCollateralAssets)  {
            collateralAssets = _totalCollateralAssets;
            collateralValue = _totalCollateralValue;
        }
    }

    /// @dev the math is based on: (Dv - x)/(Cv - (x + xf)) = LT
    /// where Dv: debt value, Cv: collateral value, LT: expected LT, f: liquidation fee, x: is value we looking for
    /// @notice in case math fail to calculate repay value, eg when collateral is not enough to cover repay and fee
    /// function will return full debt value and full collateral value, it will not revert. It is up to liquidator
    /// to make decision if it will be profitable
    /// @param _debtValue current user debt value
    /// @param _collateralValue current user collateral value
    /// @param _targetLTinBP target LT we want for user
    /// @param _liquidityFeeInBP % of `repayValue` that liquidator will use as profit from liquidating, 4 basis point
    /// eg: 100% = 1e4
    /// @param _dustThresholdInBP % in 4 basis points, repayValue/_debtValue will be over that %,
    /// then we force full liquidation
    function calculateMaxLiquidationValues(
        uint256 _debtValue,
        uint256 _collateralValue,
        uint256 _targetLTinBP,
        uint256 _liquidityFeeInBP,
        uint256 _dustThresholdInBP
    )
        internal pure returns (uint256 receiveCollateralValue, uint256 repayValue)
    {
        if (_debtValue == 0) return (0, 0);

        // this will cover case when _collateralValue == 0
        if (_targetLTinBP == 0 || _debtValue >= _collateralValue) {
            return (_collateralValue, _debtValue);
        }

        uint256 basisPoints = 1e4; // 100%
        uint256 fullFeeInBP;
        // we adding values that are 4 decimals (max 2^14), we will not overflow
        unchecked  { fullFeeInBP = basisPoints + _liquidityFeeInBP; }

        uint256 ltWithFeeInBP;
        // all values are max 2^14 (4 basis points), so safe to uncheck
        unchecked { ltWithFeeInBP = _targetLTinBP * fullFeeInBP / basisPoints; }

        if (ltWithFeeInBP >= basisPoints) { // if we over 100% with fee, then we return all
            return (_collateralValue, _debtValue);
        }

        // sub is safe because of above `if (divider > oneHundredFee)`
        unchecked { ltWithFeeInBP = basisPoints - ltWithFeeInBP; }

        uint256 targetLTTimesCollateral = _targetLTinBP * _collateralValue / basisPoints;

        if (_debtValue < targetLTTimesCollateral) {
            return (_collateralValue, _debtValue);
        }

        // subtraction is save because of above `if (_debtValue < targetLT_X_Collateral)`, div is safe
        unchecked { repayValue = (_debtValue - targetLTTimesCollateral) / ltWithFeeInBP; }

        unchecked {
            if (repayValue / _debtValue > _dustThresholdInBP) {
                return (_debtValue, _collateralValue);
            }
        }

        receiveCollateralValue = repayValue * fullFeeInBP;
        unchecked { receiveCollateralValue /= basisPoints; }
    }
}
