// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {NewMarketTest} from "silo-core/test/foundry/newMarkets/common/NewMarket.sol";

contract BeS_wS_Test is NewMarketTest {
    constructor() NewMarketTest(21788712, 0xEd7f8C077711B86b574ed94bB84895fbf147Cd8e, 1_001_720, 1_000_000) {}
}
