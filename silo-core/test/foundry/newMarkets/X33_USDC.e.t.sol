// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {NewMarketTest} from "silo-core/test/foundry/newMarkets/common/NewMarket.sol";

contract X33_USDC_Test is NewMarketTest {
    constructor() NewMarketTest(17279195, 0x18555e17A97974A07841F652E45263b9CE8AD369, 3961, 100) {}
}
