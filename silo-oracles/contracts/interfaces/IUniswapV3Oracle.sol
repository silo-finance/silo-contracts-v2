// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import {IUniswapV3Pool} from "uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from  "uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {UniswapV3OracleConfig} from "../uniswapV3/UniswapV3OracleConfig.sol";

interface IUniswapV3Oracle {
    struct UniswapV3OracleInitConfig {
        // UniV3 pool address that is used for TWAP price
        IUniswapV3Pool pool;

        // Asset in which oracle denominates its price
        address quoteToken;

        // TWAP period in seconds.
        // Number of seconds for which time-weighted average should be calculated, ie. 1800 means 30 min
        uint32 periodForAvgPrice;

        // Estimated blockchain block time with 1 decimal, with uint8 max is 25.5s
        uint8 blockTime;
    }

    /// @dev this is UniswapV3OracleInitConfig + quoteToken
    struct UniswapV3OracleSetup {
        // UniV3 pool address that is used for TWAP price
        IUniswapV3Pool pool;

        // Asset in which oracle denominates its price
        address quoteToken;

        // TWAP period in seconds.
        // Number of seconds for which time-weighted average should be calculated, ie. 1800 means 30 min
        uint32 periodForAvgPrice;

        uint16 requiredCardinality;
    }

    /// @param configAddress UniswapV3OracleConfig config contract address
    event OracleInit(UniswapV3OracleConfig configAddress);
}
