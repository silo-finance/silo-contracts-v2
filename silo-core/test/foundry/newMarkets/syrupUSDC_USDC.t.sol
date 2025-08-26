// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {NewMarketTest} from "silo-core/test/foundry/newMarkets/common/NewMarket.sol";

contract SyrupUSDC_USDC_Test is NewMarketTest {
    constructor() NewMarketTest(BlockChain.ARBITRUM, 372449494, 0x6Fb80aFD7DCa6e91ac196C3F3aDA3115E186ed11, 112, 100) {}
}
