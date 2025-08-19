// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {NewMarketTest} from "silo-core/test/foundry/newMarkets/common/NewMarket.sol";

contract sAVAX_WAVAX_2_Avalanche_Test is NewMarketTest {
    constructor() NewMarketTest(BlockChain.AVALANCHE, 67310398, 0x4592c27A4A3FEec2123953369684b1F61309ac08, 1218, 1000) {}
}
