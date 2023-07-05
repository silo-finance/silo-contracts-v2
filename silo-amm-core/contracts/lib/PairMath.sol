// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.6 <0.9.0;

library PairMath {
    uint256 constant internal _PRECISION = 1e18;

    /// @dev fee basis points
    uint256 constant internal _FEE_BP = 1e4;

    /// @dev expose FEE_BP for QA purposes
    function feeBp() public pure returns (uint256) {
        return _FEE_BP;
    }

    /// @param _debtQuote debt amount that is needed for expected collateral out during swap
    /// @param _onSwapK result of `_onSwapCalculateK()`
    /// @param _fee fee in basis points
    /// @return debtAmountIn adjusted amount of debt token (exact in)
    /// @return amountInForSwap amount that wil be swapped, reduced by fee
    /// @return fee protocol fee amount, that is part of `debtAmountIn`
    function getDebtIn(uint256 _debtQuote, uint256 _onSwapK, uint256 _fee)
        internal
        pure
        returns (uint256 debtAmountIn, uint256 amountInForSwap, uint256 fee)
    {
        debtAmountIn = _onSwapK * _debtQuote;

        unchecked {
            // div is safe
            // div(PRECISION) because of K
            debtAmountIn = debtAmountIn / _PRECISION;
        }

        if (_fee != 0) {
            unchecked {
                // unchecked (mul): fee on Amm pair can be at most 10%, so user will have to have 90% of all
                // available tokens and total tokens must be 2^256 and only then we will overflow
                // unchecked (sub, div): _fee is less than _FEE_BP, so we will not underflow on sub
                // and it will not be div(0)
                debtAmountIn = debtAmountIn * _FEE_BP / (_FEE_BP - _fee);
                fee = debtAmountIn * _fee / _FEE_BP;
                // fee is always less than debtAmountIn, so we can not underflow
                amountInForSwap = debtAmountIn - fee;
            }
        } else {
            amountInForSwap = debtAmountIn;
        }
    }

    /// @dev this is reverse of what `getDebtIn()` does
    /// @param _onSwapK result of `_onSwapCalculateK()`
    /// @param _debtAmountIn amount of debt token that user wants to swap (exact in)
    /// @param _fee fee in basis points
    /// @return debtQuote adjusted debt amount that will be used to get quote for collateral, that amount will be swap
    /// (if fee==0, `debtQuote` will be equal or greater than `_debtAmountIn` because over time we get more collateral)
    /// @return fee protocol fee amount that is part of `_debtAmountIn`
    function getDebtInReverse(uint256 _debtAmountIn, uint256 _onSwapK, uint256 _fee)
        internal
        pure
        returns (uint256 debtQuote, uint256 fee)
    {
        if (_fee != 0) {
            unchecked {
                // fee calculations unchecked: fee on Amm pair can be at most 10%, so user will have to have 90% of all
                // available tokens and total tokens must be 2^256 and only then we will overflow
                fee = _debtAmountIn * _fee / _FEE_BP;
                // unchecked: fee is chunk of _amountIn so we can not underflow
                _debtAmountIn -= fee;
            }
        }

        // TODO uncheck?
        debtQuote = _debtAmountIn * _PRECISION;

        unchecked {
            // div is safe
            debtQuote /= _onSwapK;
        }
    }
}
