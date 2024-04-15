// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {DynamicKinkModelV1} from "../../../contracts/interestRateModel/DynamicKinkModelV1.sol";

// FOUNDRY_PROFILE=core forge test -vv --mc DynamicKinkModelV1Test
contract DynamicKinkModelV1Test is Test {
    uint256 constant TODAY = 1682885514;
    DynamicKinkModelV1 immutable INTEREST_RATE_MODEL;

    uint256 constant DP = 10 ** 18;

    constructor() {
        INTEREST_RATE_MODEL = new DynamicKinkModelV1();
    }

    function test_12345() public {
        assertEq(INTEREST_RATE_MODEL.DECIMALS(), DP);
    }
}
