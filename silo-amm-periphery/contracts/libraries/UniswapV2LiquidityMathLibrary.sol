// SPDX-License-Identifier: GD
pragma solidity >=0.8.0;

import "../external/Babylonian.sol";
import "../interfaces/ISiloAmmPair.sol";

import "./FullMath.sol";
import "./UniswapV2Library.sol";

/// @dev this is based on UniswapV2Library
/// differences in interface are mentioned in `notice` section of each method
///
/// library containing some math for dealing with the liquidity shares of a pair, e.g. computing their exact value
/// in terms of the underlying tokens
library UniswapV2LiquidityMathLibrary {
    error LIB_ZERO_PAIR_RESERVES();
    error COMPUTE_LIQUIDITY_VALUE_LIQUIDITY_AMOUNT();

    /// @notice differences from original UniswapV2Library:
    /// - first argument is changed from factory address to pair address
    /// @dev gets the reserves after an arbitrage moves the price to the profit-maximizing ratio given an externally
    /// observed true price
    function getReservesAfterArbitrage(
        IUniswapV2Pair _pair,
        address _tokenA,
        address _tokenB,
        uint256 _truePriceTokenA,
        uint256 _truePriceTokenB
    ) internal view returns (uint256 reserveA, uint256 reserveB) {
        // first get reserves before the swap
        (reserveA, reserveB) = UniswapV2Library.getReserves(_pair, _tokenA, _tokenB);

        if (reserveA == 0 || reserveB == 0) revert LIB_ZERO_PAIR_RESERVES();

        // then compute how much to swap to arb to the true price
        (
            bool aToB,
            uint256 amountIn
        ) = computeProfitMaximizingTrade(_truePriceTokenA, _truePriceTokenB, reserveA, reserveB);

        if (amountIn == 0) {
            return (reserveA, reserveB);
        }

        // now affect the trade to the reserves
        if (aToB) {
            uint amountOut = UniswapV2Library.getAmountOut(amountIn, reserveA, reserveB);
            unchecked {
                reserveA += amountIn;
                reserveB -= amountOut;
            }
        } else {
            uint amountOut = UniswapV2Library.getAmountOut(amountIn, reserveB, reserveA);
            unchecked {
                reserveB += amountIn;
                reserveA -= amountOut;
            }
        }
    }

    /// @notice differences from original UniswapV2Library:
    /// - first argument is changed from factory address to pair address
    /// **note this is subject to manipulation, e.g. sandwich attacks**. prefer passing a manipulation resistant price
    /// to #getLiquidityValueAfterArbitrageToPrice
    /// @dev get all current parameters from the pair and compute value of a liquidity amount
    function getLiquidityValue(
        IUniswapV2Pair _pair,
        address _tokenA,
        address _tokenB,
        uint256 _liquidityAmount
    ) internal view returns (uint256 tokenAAmount, uint256 tokenBAmount) {
        (uint256 reservesA, uint256 reservesB) = UniswapV2Library.getReserves(_pair, _tokenA, _tokenB);
        bool feeOn = ISiloAmmPair(address(_pair)).feeTo() != address(0);
        uint kLast = feeOn ? _pair.kLast() : 0;
        uint totalSupply = _pair.totalSupply();
        return computeLiquidityValue(reservesA, reservesB, totalSupply, _liquidityAmount, feeOn, kLast);
    }

    /// @notice differences from original UniswapV2Library:
    /// - first argument is changed from factory address to pair address
    /// @dev given two tokens, tokenA and tokenB, and their "true price", i.e. the observed ratio of value of token A to
    /// token B, and a liquidity amount, returns the value of the liquidity in terms of tokenA and tokenB
    function getLiquidityValueAfterArbitrageToPrice(
        IUniswapV2Pair _pair,
        address _tokenA,
        address _tokenB,
        uint256 _truePriceTokenA,
        uint256 _truePriceTokenB,
        uint256 _liquidityAmount
    ) internal view returns (
        uint256 tokenAAmount,
        uint256 tokenBAmount
    ) {
        bool feeOn = ISiloAmmPair(address(_pair)).feeTo() != address(0);
        uint kLast = feeOn ? _pair.kLast() : 0;
        uint totalSupply = _pair.totalSupply();

        // this also checks that totalSupply > 0
        if (!(totalSupply >= _liquidityAmount && _liquidityAmount != 0)) {
            revert COMPUTE_LIQUIDITY_VALUE_LIQUIDITY_AMOUNT();
        }

        (
            uint reservesA,
            uint reservesB
        ) = getReservesAfterArbitrage(_pair, _tokenA, _tokenB, _truePriceTokenA, _truePriceTokenB);

        return computeLiquidityValue(reservesA, reservesB, totalSupply, _liquidityAmount, feeOn, kLast);
    }

    /// @dev computes the direction and magnitude of the profit-maximizing trade
    function computeProfitMaximizingTrade(
        uint256 _truePriceTokenA,
        uint256 _truePriceTokenB,
        uint256 _reserveA,
        uint256 _reserveB
    ) internal pure returns (bool aToB, uint256 amountIn) {
        aToB = FullMath.mulDiv(_reserveA, _truePriceTokenB, _reserveB) < _truePriceTokenA;

        uint256 invariant = _reserveA * _reserveB;

        uint256 leftSide = Babylonian.sqrt(
            FullMath.mulDiv(
                invariant * 1000,
                aToB ? _truePriceTokenA : _truePriceTokenB,
                (aToB ? _truePriceTokenB : _truePriceTokenA) * 997
            )
        );

        uint256 rightSide = (aToB ? _reserveA * 1000 : _reserveB * 1000);
        unchecked { rightSide /= 997; }

        if (leftSide < rightSide) return (false, 0);

        // compute the amount that must be sent to move the price to the profit-maximizing price
        amountIn = leftSide - rightSide;
    }

    /// @dev computes liquidity value given all the parameters of the pair
    function computeLiquidityValue(
        uint256 _reservesA,
        uint256 _reservesB,
        uint256 _totalSupply,
        uint256 _liquidityAmount,
        bool _feeOn,
        uint _kLast
    ) internal pure returns (uint256 tokenAAmount, uint256 tokenBAmount) {
        if (_feeOn && _kLast != 0) {
            uint rootK = Babylonian.sqrt(_reservesA * _reservesB);
            uint rootKLast = Babylonian.sqrt(_kLast);
            if (rootK != rootKLast) {
                uint numerator1 = _totalSupply;
                uint numerator2 = rootK - rootKLast;
                uint denominator = rootK * 5 + rootKLast;
                uint feeLiquidity = FullMath.mulDiv(numerator1, numerator2, denominator);
                _totalSupply = _totalSupply + feeLiquidity;
            }
        }

        uint256 a =  _reservesA * _liquidityAmount;
        uint256 b = _reservesB * _liquidityAmount;

        unchecked {
            return (a / _totalSupply, b / _totalSupply);
        }
    }
}
