// SPDX-License-Identifier: GD
pragma solidity >=0.8.0;

import "silo-amm-core/contracts/interfaces/ISiloAmmPair.sol";

import "../external/Babylonian.sol";

import "./FullMath.sol";
import "./UniswapV2Library.sol";

/// @dev this is based on UniswapV2Library
/// differences in interface are mentioned in `notice` section of each method
///
/// library containing some math for dealing with the liquidity shares of a pair, e.g. computing their exact value
/// in terms of the underlying tokens
library UniswapV2LiquidityMathLibrary {
    error NOT_SUPPORTED();
    error LIB_ZERO_PAIR_RESERVES();
    error COMPUTE_LIQUIDITY_VALUE_LIQUIDITY_AMOUNT();

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

    /// @dev computes the direction and magnitude of the profit-maximizing trade
    /// TODO here we can calculate, when (in how many seconds in future) price will be the TRUE price
    /// OR we can go over pools?? but this can be done off-chain
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
