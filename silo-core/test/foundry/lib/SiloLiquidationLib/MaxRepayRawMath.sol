// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

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
        uint256 _liquidityFee
    )
        internal pure returns (uint256 repayValue)
    {
        repayValue = (
            _totalBorrowerDebtValue - _ltvAfterLiquidation * _totalBorrowerCollateralValue / _DECIMALS_POINTS
        ) * _DECIMALS_POINTS / (
            _DECIMALS_POINTS - _ltvAfterLiquidation - _ltvAfterLiquidation * _liquidityFee / _DECIMALS_POINTS
        );

        return repayValue > _totalBorrowerDebtValue ? _totalBorrowerDebtValue : repayValue;
    }
}
