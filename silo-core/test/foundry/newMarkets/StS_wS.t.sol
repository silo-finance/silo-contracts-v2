// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {NewMarketTest} from "silo-core/test/foundry/newMarkets/common/NewMarket.sol";

contract StS_wS_Test is NewMarketTest {
    constructor() NewMarketTest(16133130, 0xA3BF8b1eE377bBe6152A6885eaeE8747dcBEa35D, 6158, 6073) {}
}
