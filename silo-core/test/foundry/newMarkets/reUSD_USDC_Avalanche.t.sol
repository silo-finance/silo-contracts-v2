// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {NewMarketTest} from "silo-core/test/foundry/newMarkets/common/NewMarket.sol";

contract reUSD_USDC_Avalanche_Test is NewMarketTest {
    constructor() NewMarketTest(BlockChain.AVALANCHE, 67064078, 0x98f0ac5930E09F996650e4aC0Fc8D7578a0Caaab, 101, 100) {}
}
