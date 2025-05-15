// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {NewMarketTest} from "silo-core/test/foundry/newMarkets/common/NewMarket.sol";

contract WstkscUSD_USDC_Test is NewMarketTest {
    constructor() NewMarketTest(25262769, 0x243D2d11Fd323B929a2756C81AfA455200134FCA, 100429, 100000) {}
}
