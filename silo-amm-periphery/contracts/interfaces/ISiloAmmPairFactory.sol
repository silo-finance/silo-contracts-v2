// SPDX-License-Identifier: GD
pragma solidity >=0.5.0;

import "silo-amm-core/contracts/external/interfaces/IUniswapV2Pair.sol";

/// @dev this is based on IUniswapV2Factory, unfortunately we was not able to replicate it entirely
interface ISiloAmmPairFactory {
    function createPair(address silo, address tokenA, address tokenB, address feeTo)
        external
        returns (IUniswapV2Pair pair);
}
