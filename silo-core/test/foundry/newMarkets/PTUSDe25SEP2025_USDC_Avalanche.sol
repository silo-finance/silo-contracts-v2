// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {NewMarketTest} from "silo-core/test/foundry/newMarkets/common/NewMarket.sol";

contract PTUSDe25SEP2025_USDC_Avalanche_Test is NewMarketTest {
    constructor() NewMarketTest(BlockChain.AVALANCHE, 67007469, 0xc68ED9C0C4dc4BdEE60E43f519374bFd18F738B2, 983, 1000) {}
}
