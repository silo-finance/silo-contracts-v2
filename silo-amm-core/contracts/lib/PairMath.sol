// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.6 <0.9.0;

library PairMath {
    uint256 constant PRECISION = 1e18;

    /// @param _debtQuote debt amount that we want to swap
    /// @param _onSwapK result of `_onSwapCalculateK()`
    /// @return debtAmountIn adjusted amount of debt token that will be swap (it will be equal or less `_debtQuote`
    function getDebtIn(uint256 _debtQuote, uint256 _onSwapK)
        internal
        pure
        returns (uint256 debtAmountIn)
    {
        debtAmountIn = _onSwapK * _debtQuote;

        unchecked {
            // div is safe
            // div(PRECISION) because of K
            return debtAmountIn / PRECISION;
        }
    }

    /// @dev this is reverse of what `getDebtIn()` does
    /// @param _onSwapK result of `_onSwapCalculateK()`
    /// @param _amountIn amount of debt token that user expect to swap
    /// @param debtIn adjusted debt amount that will be used to get quote for collateral
    /// (if will be equal or greater than `_debtAmountIn`)
    function getDebtInReverse(uint256 _amountIn, uint256 _onSwapK)
        internal
        pure
        returns (uint256 debtIn)
    {
        debtIn = _amountIn * PRECISION;

        unchecked {
            // div is safe
            return debtIn / _onSwapK;
        }
    }
}
