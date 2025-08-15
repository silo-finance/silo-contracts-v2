// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {NewMarketTest} from "silo-core/test/foundry/newMarkets/common/NewMarket.sol";

contract reUSD_USDC_Avalanche_Test is NewMarketTest {
    constructor() NewMarketTest(BlockChain.AVALANCHE, 67107126, 0xCcEB4356F5958e0E7a69Dd5c7A8B2aB730951819, 101, 100) {}
}
