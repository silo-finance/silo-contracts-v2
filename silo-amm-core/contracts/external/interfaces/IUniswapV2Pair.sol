// SPDX-License-Identifier: GD
pragma solidity >=0.5.0;


/// @dev cleaned version of original IUniswapV2Pair
/// Main reason for cleanup is this error:
/// `TypeError: Derived contract must override function "transferFrom". Two or more base classes define...`.
/// Also removed IUniswapV2ERC20 as Silo pair is not ERC20
interface IUniswapV2Pair {
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );

    /// @notice originally this method does not return anything
    /// @return amountIn amount of debt token spend on swap
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data)
        external
        returns (uint256 amountIn);

    function initialize(address, address) external;

    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function MINIMUM_LIQUIDITY() external pure returns (uint); // solhint-disable-line func-name-mixedcase
}
