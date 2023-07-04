// SPDX-License-Identifier: GD
pragma solidity >=0.6.2;

/// @dev source: uniswap
/// It had to be cloned because of `factory()` and `WETH()` methods, they are marked as pure but we need them to be view
/// and there is no way to override this.
interface IUniswapV2Router01 {
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);

    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);

    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);

    /// @param _amountIn initial, exact amount of first token to swap
    /// @param _amountOutMin minimal expected amount of last token out
    /// @param _path in Silo there might be multiple pools for same pair of tokens, so path must include pool address,
    /// path must be composed in that way: [tokenIn, pool, tokenOut, ...] so for single swap you need to provide
    /// 3 addresses token-pool-token. In case of 2 swaps and more, tokenOut became tokenIn for next swap etc.
    /// @param _to address of swap receiver
    /// @param _deadline time when swap will expire
    /// @return amounts array of amounts out for each swap
    function swapExactTokensForTokens(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address[] calldata _path,
        address _to,
        uint256 _deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);

    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);

    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function factory() external view returns (address);
    function WETH() external view returns (address); // solhint-disable-line func-name-mixedcase

    /// @dev performs chained getAmountOut calculations on any number of pairs
    /// @param _amountIn initial, exact amount of first token to swap
    /// @param _path in Silo there might be multiple pools for same pair of tokens, so path must include pool address,
    /// path must be composed in that way: [tokenIn, pool, tokenOut, ...] so for single swap you need to provide
    /// 3 addresses token-pool-token. In case of 2 swaps and more, tokenOut became tokenIn for next swap etc.
    /// @return amounts array of amounts out for each swap
    function getAmountsOut(
        uint256 _amountIn,
        address[] calldata _path
    ) external view returns (uint256[] memory amounts);

    /// @param _timestamp time for which calculations are done, price in Silo can change over time
    function getAmountsOut(
        uint256 _amountIn,
        address[] calldata _path,
        uint256 _timestamp
    ) external view returns (uint256[] memory amounts);

    /// @dev performs chained getAmountOut calculations on any number of pairs
    /// @param _amountOut  exact amount out that is expected to get after swap
    /// @param _path in Silo there might be multiple pools for same pair of tokens, so path must include pool address,
    /// path must be composed in that way: [tokenIn, pool, tokenOut, ...] so for single swap you need to provide
    /// 3 addresses token-pool-token. In case of 2 swaps and more, tokenOut became tokenIn for next swap etc.
    /// @return amounts array of amounts out for each swap
    function getAmountsIn(
        uint256 _amountOut,
        address[] calldata _path
    ) external view returns (uint256[] memory amounts);

    /// @param _timestamp time for which calculations are done, price in Silo can change over time
    function getAmountsIn(
        uint256 _amountOut,
        address[] calldata _path,
        uint256 _timestamp
    ) external view returns (uint256[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
}
