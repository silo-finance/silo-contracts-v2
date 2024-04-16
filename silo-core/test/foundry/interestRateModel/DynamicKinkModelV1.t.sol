// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {DynamicKinkModelV1} from "../../../contracts/interestRateModel/DynamicKinkModelV1.sol";
import "../data-readers/RcompTestDynamicKink.sol";

// FOUNDRY_PROFILE=core forge test -vv --mc DynamicKinkModelV1Test
contract DynamicKinkModelV1Test is RcompTestDynamicKink {
    uint256 constant TODAY = 1682885514;
    DynamicKinkModelV1 immutable INTEREST_RATE_MODEL;

    int256 constant DP = 10 ** 18;

    constructor() {
        INTEREST_RATE_MODEL = new DynamicKinkModelV1();
    }

    function test_12345() public {
        RcompData[] memory data = _readDataFromJson();
        assertEq(INTEREST_RATE_MODEL.DECIMALS(), 18);

        for (uint i; i < data.length; i++) {
            (IDynamicKinkModelV1.Setup memory setup, Debug memory debug) = _toSetup(data[i]);

            (int256 rcomp, int256 k) = INTEREST_RATE_MODEL.compoundInterestRate(
                setup,
                data[i].input.lastTransactionTime,
                data[i].input.currentTime,
                data[i].input.lastUtilization
            );

            emit log_string("******\n\n\n\n");
            emit log_named_int("return: rcomp", rcomp);
            emit log_named_int("return: k", k);
            emit log_named_int("expected: rcomp", data[i].expected.compoundInterest);
            emit log_named_int("expected: k", data[i].expected.newSlope);
            emit log_named_int("relative error for rcomp in 10^18 bp new/expected", rcomp * DP / data[i].expected.compoundInterest);
            emit log_named_int("relative error for k in 10^18 bp new/expected", k * DP / data[i].expected.newSlope);
        }
    }
}
