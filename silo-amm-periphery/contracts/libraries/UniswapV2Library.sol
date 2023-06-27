// SPDX-License-Identifier: GD
pragma solidity >=0.8.0;

import "silo-amm-core/contracts/interfaces/ISiloAmmPair.sol";

/// @dev this is based on UniswapV2Library
/// differences in interface are mentioned in `notice` section of each method
/// `path` array is different from original Uniswap argument, here it is combination of tokens and pairs
/// eg: [tokenB][pairAB][tokenA], or for 2 swaps: [tokenB][pairAB][tokenA][pairAC][tokenC]
/// there might be many pairs for same tokens, this is why pair address needs to be specified
library UniswapV2Library {
    error LIB_ZERO_ADDRESS();
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

    /// @notice Calculation might be wrong if `_path` includes same pair for same swap twice
    /// @notice differences from original UniswapV2Library:
    /// - `factory` was removed from list or arguments
    /// - `path` includes pairs addresses
    /// @dev performs chained getAmountOut calculations on any number of pairs
    /// @param _amountIn initial, exact amount of first token to swap
    /// @param _path in Silo there might be multiple pools for same pair of tokens, so path must include pool address,
    /// path must be composed in that way: [tokenIn, pool, tokenOut, ...] so for single swap you need to provide
    /// 3 addresses token-pool-token. In case of 2 swaps and more, tokenOut became tokenIn for next swap etc.
    /// @return amounts array of amounts out for each swap
    function getAmountsOut(uint256 _amountIn, address[] calldata _path, uint256 _timestamp)
        internal
        view
        returns (uint256[] memory amounts)
    {
        if (_path.length < 3) revert LIB_INVALID_PATH();

        unchecked {
            amounts = new uint[]((_path.length + 1 ) / 2);
            amounts[0] = _amountIn;
            uint256 count = _path.length - 2;

            for (uint256 i; i < count; i += 2) {
                _amountIn = ISiloAmmPair(_path[i + 1]).getAmountOut(_path[i], _amountIn, _timestamp);
                amounts[i + 1] = _amountIn;
            }
        }
    }

    /// @notice Calculation might be wrong if `_path` includes same pair for same swap twice
    /// @notice differences from original UniswapV2Library:
    /// - `factory` was removed from list of arguments
    /// - `path` includes pairs addresses
    /// @dev performs chained getAmountIn calculations on any number of pairs
    /// @param _amountOut expected exact amount of tokens out after swap
    /// @param _path in Silo there might be multiple pools for same pair of tokens, so path must include pool address,
    /// path must be composed in that way: [tokenIn, pool, tokenOut, ...] so for single swap you need to provide
    /// 3 addresses token-pool-token. In case of 2 swaps and more, tokenOut became tokenIn for next swap etc.
    function getAmountsIn(uint256 _amountOut, address[] memory _path, uint256 _timestamp)
        internal
        view
        returns (uint256[] memory amounts)
    {
        if (_path.length < 3) revert LIB_INVALID_PATH();

        unchecked {
            uint256 amountsLength = (_path.length + 1) / 2;
            amounts = new uint256[](amountsLength);
            amounts[amountsLength - 1] = _amountOut;
            uint256 count = amountsLength;

            for (uint i = count; i > 1; i -= 2) {
                _amountOut = ISiloAmmPair(_path[i - 1]).getAmountIn(_path[i], _amountOut, _timestamp);
                amounts[i - 2] = _amountOut;
            }
        }
    }

    /// @dev returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address _tokenA, address _tokenB) internal pure returns (address token0, address token1) {
        (token0, token1) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
        if (token0 == address(0)) revert LIB_ZERO_ADDRESS();
    }
}
