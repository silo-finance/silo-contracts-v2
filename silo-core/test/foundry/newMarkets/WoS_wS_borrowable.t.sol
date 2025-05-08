// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {NewMarketTest} from "silo-core/test/foundry/newMarkets/common/NewMarket.sol";

contract WoS_wS_borrowable_Test is NewMarketTest {
    constructor() NewMarketTest(25254578, 0x0FF333b3c7e12Ae53cFAeD98232541C06D7CD2ab, 1024, 1000) {}
}
