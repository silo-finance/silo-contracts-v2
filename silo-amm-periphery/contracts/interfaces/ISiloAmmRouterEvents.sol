// SPDX-License-Identifier: GD
pragma solidity >=0.5.0;

import "silo-amm-core/contracts/external/interfaces/IUniswapV2Pair.sol";
import "silo-amm-core/contracts/interfaces/ISiloAmmPair.sol";

interface ISiloAmmRouterEvents {
    /// @dev this event is here to keep backwards compatibility with original IUniswapV2Factory
    /// @notice in Silo we can have multiple pool for same tokens pair
    /// @param token0 token address, "lower" one
    /// @param token1 token address, "higher" one
    /// @param pair address of ISiloAmmPair, compatible with IUniswapV2Pair interface,
    /// this address can not be calculated using create2
    /// @param id index in `allPools` array
    event PairCreated(address indexed token0, address indexed token1, address pair, uint id);

    error NOT_SUPPORTED();
    error MOVED_TO_PAIR();
    error SILO_AMM_PAIR_FACTORY_PING();

    error WETH_ZERO();

    error IDENTICAL_ADDRESSES();
    error ZERO_ADDRESS();

    error UNISWAPV2_ROUTER_EXPIRED();
    error UNISWAPV2_ROUTER_INVALID_PATH();
    error UNISWAPV2_ROUTER_EXCESSIVE_INPUT_AMOUNT();
    error UNISWAPV2_ROUTER_INSUFFICIENT_A_AMOUNT();
    error UNISWAPV2_ROUTER_INSUFFICIENT_B_AMOUNT();
    error UNISWAPV2_ROUTER_INSUFFICIENT_OUTPUT_AMOUNT();
}
