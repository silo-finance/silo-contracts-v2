// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {NewMarketTest} from "silo-core/test/foundry/newMarkets/common/NewMarket.sol";

contract EURCe_USDCe_Test is NewMarketTest {
    constructor() NewMarketTest(25257462 , 0xaE5A3b4F482c7dBb219E4AE3E5Bb975dE3a28d56, 113, 100) {}
}
