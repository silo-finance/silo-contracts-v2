// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {NewMarketTest} from "silo-core/test/foundry/newMarkets/common/NewMarket.sol";

contract savUSD_USDC_3_Avalanche_Test is NewMarketTest {
    constructor() NewMarketTest(BlockChain.AVALANCHE, 67109311, 0x33fAdB3dB0A1687Cdd4a55AB0afa94c8102856A1, 1068, 1000) {}
}
