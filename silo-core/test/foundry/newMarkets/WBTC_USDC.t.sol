// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {NewMarketTest} from "silo-core/test/foundry/newMarkets/common/NewMarket.sol";

contract WBTC_USDC_Test is NewMarketTest {
    constructor() NewMarketTest(17433664, 0x2F33cCbB08743d51E086BDC1bA20fB8CEB9bAD40, 84240_00, 1_00) {}
}
