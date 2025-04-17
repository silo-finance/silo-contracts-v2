// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {NewMarketTest} from "silo-core/test/foundry/newMarkets/common/NewMarket.sol";

contract FrxUSD_scUSD_Test is NewMarketTest {
    constructor() NewMarketTest(16123358, 0x6452b9aE8011800457b42C4fBBDf4579afB96228, 112, 100) {}
}
