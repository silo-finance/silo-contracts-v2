// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {NewMarketTest} from "silo-core/test/foundry/newMarkets/common/NewMarket.sol";

contract wOS_wS_Test is NewMarketTest {
    constructor() NewMarketTest(BlockChain.SONIC, 42498314, 0x10AD9dD6f1250D496f1Cb65b7cB3C33A3605e1DC, 3216, 3125) {}
}
