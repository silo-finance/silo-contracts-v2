// SPDX-License-Identifier: GD
pragma solidity >=0.8.0;

import "silo-amm-core/contracts/external/interfaces/IUniswapV2Pair.sol";

/// @dev this is based on UniswapV2Library
/// differences in interface are mentioned in `notice` section of each method
/// `path` array is different from original Uniswap argument, here it is combination of tokens and pairs
/// eg: [tokenB][pairAB][tokenA], or for 2 swaps: [tokenB][pairAB][tokenA][pairAC][tokenC]
/// there might be many pairs for same tokens, this is why pair address needs to be specified
library UniswapV2Library {
    error LIB_ZERO_ADDRESS();
    error LIB_INSUFFICIENT_AMOUNT();
    error LIB_INSUFFICIENT_LIQUIDITY();
    error LIB_INSUFFICIENT_INPUT_AMOUNT();
    error LIB_INSUFFICIENT_OUTPUT_AMOUNT();
    error LIB_INVALID_PATH();

    /// @notice differences from original UniswapV2Library:
    /// - first argument is changed from factory address to pair address
    /// @dev fetches and sorts the reserves for a pair
    function getReserves(IUniswapV2Pair _pair, address _tokenA, address _tokenB)
        internal
        view
        returns (uint reserveA, uint reserveB)
    {
        (address token0,) = sortTokens(_tokenA, _tokenB);
        (uint reserve0, uint reserve1,) = _pair.getReserves();
        (reserveA, reserveB) = _tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    /// @notice differences from original UniswapV2Library:
    /// - `factory` was removed from list or arguments
    /// - `path` includes pairs addresses
    /// @dev performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(uint _amountIn, address[] memory _path)
        internal
        view
        returns (uint[] memory amounts)
    {
        if (_path.length < 3) revert LIB_INVALID_PATH();

        unchecked {
            uint256 amountsLength = (_path.length + 1 ) / 2;
            amounts = new uint[](amountsLength);
            amounts[0] = _amountIn;
            uint256 count = _path.length - 2;

            for (uint i; i < count; i+=2) {
                (uint reserveIn, uint reserveOut) = getReserves(IUniswapV2Pair(_path[i + 1]), _path[i], _path[i + 2]);
                amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
            }
        }
    }

    /// @notice differences from original UniswapV2Library:
    /// - `factory` was removed from list or arguments
    /// - `path` includes pairs addresses
    /// @dev performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(uint _amountOut, address[] memory _path)
        internal
        view
        returns (uint[] memory amounts)
    {
        if (_path.length < 3) revert LIB_INVALID_PATH();

        unchecked {
            uint256 amountsLength = (amounts.length + 1) / 2;
            amounts = new uint[](amountsLength);
            amounts[amountsLength - 1] = _amountOut;
            uint256 count = _path.length - 2;

            for (uint i = count; i > 2; i -= 2) {
                (uint reserveIn, uint reserveOut) = getReserves(IUniswapV2Pair(_path[i - 1]), _path[i - 2], _path[i]);
                amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
            }
        }
    }

    /// @dev returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address _tokenA, address _tokenB) internal pure returns (address token0, address token1) {
        (token0, token1) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
        if (token0 == address(0)) revert LIB_ZERO_ADDRESS();
    }

    /// @dev given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint _amountA, uint _reserveA, uint _reserveB) internal pure returns (uint amountB) {
        if (_amountA == 0) revert LIB_INSUFFICIENT_AMOUNT();
        if (_reserveA == 0 || _reserveB == 0) revert LIB_INSUFFICIENT_LIQUIDITY();

        amountB = _amountA * _reserveB;
        unchecked { amountB /= _reserveA; }
    }

    /// @dev given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint _amountIn, uint _reserveIn, uint _reserveOut) internal pure returns (uint amountOut) {
        if (_amountIn == 0) revert LIB_INSUFFICIENT_INPUT_AMOUNT();
        if (_reserveIn == 0 || _reserveOut == 0) revert LIB_INSUFFICIENT_LIQUIDITY();

        uint amountInWithFee = _amountIn * 997;
        uint numerator = amountInWithFee * _reserveOut;
        uint denominator = _reserveIn * 1000 + amountInWithFee;
        unchecked { amountOut = numerator / denominator; }
    }

    /// @dev given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint _amountOut, uint _reserveIn, uint _reserveOut) internal pure returns (uint amountIn) {
        if (_amountOut == 0) revert LIB_INSUFFICIENT_OUTPUT_AMOUNT();
        if (_reserveIn == 0 || _reserveOut == 0) revert LIB_INSUFFICIENT_LIQUIDITY();

        uint numerator = _reserveIn * _amountOut * 1000;
        uint denominator = _reserveOut - _amountOut * 997;
        unchecked { amountIn = numerator / denominator; }
        amountIn = amountIn + 1;
    }
}
