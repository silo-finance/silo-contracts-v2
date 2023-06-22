// SPDX-License-Identifier: GD
pragma solidity >=0.5.0;

import "uniswap/v2-core/contracts/interfaces/IUniswapV2ERC20.sol";

/// @dev cleaned version of original IUniswapV2Pair
/// Main reason for cleanup is this error:
/// `TypeError: Derived contract must override function "transferFrom". Two or more base classes define...`.
/// Also removed common part that is present in IUniswapV2ERC20
interface IUniswapV2Pair is IUniswapV2ERC20 {
    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);

    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );

    event Sync(uint112 reserve0, uint112 reserve1);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    /// @notice originally this method does not return anything
    /// @return amountIn amount of debt token spend on swap
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data)
        external
        returns (uint256 amountIn);

    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;

    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function MINIMUM_LIQUIDITY() external pure returns (uint); // solhint-disable-line func-name-mixedcase
}
