// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

// forge test -vv --mc MaxLiquidationTest
contract MaxRepayRawMath {
    uint256 private constant _DECIMALS_POINTS = 1e18;

    /// @dev the math is based on: (Dv - x)/(Cv - (x + xf)) = LT
    /// where Dv: debt value, Cv: collateral value, LT: expected LT, f: liquidation fee, x: is value we looking for
    /// x = (Dv - LT * Cv) / (DP - LT - LT * f)
    function _estimateMaxRepayValueRaw(
        uint256 _totalBorrowerDebtValue,
        uint256 _totalBorrowerCollateralValue,
        uint256 _ltvAfterLiquidation,
        uint256 _liquidationFee
    )
        internal pure returns (uint256 repayValue)
    {
        uint256 tmp = _ltvAfterLiquidation * _liquidationFee / _DECIMALS_POINTS;
        if (_ltvAfterLiquidation + tmp > _DECIMALS_POINTS) return _totalBorrowerDebtValue;

        uint256 divider =
            _DECIMALS_POINTS - _ltvAfterLiquidation - _ltvAfterLiquidation * _liquidationFee / _DECIMALS_POINTS;

        if (divider == 0) return 0;

        repayValue = (
            _totalBorrowerDebtValue - _ltvAfterLiquidation * _totalBorrowerCollateralValue / _DECIMALS_POINTS
        ) * _DECIMALS_POINTS / divider;

        return repayValue > _totalBorrowerDebtValue ? _totalBorrowerDebtValue : repayValue;
    }
}
