// SPDX-License-Identifier: GD
pragma solidity >=0.5.0;

import "silo-amm-core/contracts/external/interfaces/IUniswapV2Pair.sol";
import "silo-amm-core/contracts/interfaces/IAmmPriceModel.sol";
import "silo-amm-core/contracts/external/interfaces/ISiloOracle.sol";

import "../external/interfaces/IUniswapV2Router02.sol";

interface ISiloAmmRouter is IUniswapV2Router02 {
    /// @dev this event is here to keep backwards compatibility with IUniswapV2Factory
    event PairCreated(address indexed token0, address indexed token1, IUniswapV2Pair pair, uint id);

    /// @param silo address
    event PairCreated(
        address indexed token0,
        address indexed token1,
        IUniswapV2Pair pair,
        address indexed silo,
        uint id
    );

    error NOT_SUPPORTED();

    error IDENTICAL_ADDRESSES();
    error ZERO_ADDRESS();
    error PAIR_EXISTS();

    error UNISWAPV2_ROUTER_EXPIRED();
    error UNISWAPV2_ROUTER_INVALID_PATH();
    error UNISWAPV2_ROUTER_EXCESSIVE_INPUT_AMOUNT();
    error UNISWAPV2_ROUTER_INSUFFICIENT_A_AMOUNT();
    error UNISWAPV2_ROUTER_INSUFFICIENT_B_AMOUNT();
    error UNISWAPV2_ROUTER_INSUFFICIENT_OUTPUT_AMOUNT();

    function createPair(
        address _token0,
        ISiloOracle _oracle0,
        address _token1,
        ISiloOracle _oracle1,
        IAmmPriceModel.AmmPriceConfig memory _config,
        address _feeTo
    ) external returns (IUniswapV2Pair pair);

    function getPair(address silo, address tokenA, address tokenB) external view returns (IUniswapV2Pair pair);
    function getPairs(address tokenA, address tokenB) external view returns (IUniswapV2Pair[] memory pairs);

    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);
}
