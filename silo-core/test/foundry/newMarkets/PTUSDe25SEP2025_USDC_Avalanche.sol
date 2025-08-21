// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {NewMarketTest} from "silo-core/test/foundry/newMarkets/common/NewMarket.sol";

contract PTUSDe25SEP2025_USDC_Avalanche_Test is NewMarketTest {
    constructor() 
        NewMarketTest(BlockChain.AVALANCHE, 67414010, 0x674f210036E1AC458571C3497D7DA7F460b71853, 1000, 1000) 
    {}
}
