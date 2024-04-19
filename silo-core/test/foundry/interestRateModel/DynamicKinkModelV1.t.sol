// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {DynamicKinkModelV1} from "../../../contracts/interestRateModel/DynamicKinkModelV1.sol";
import "../data-readers/RcompTestDynamicKink.sol";
import "../data-readers/RcurTestDynamicKink.sol";

// FOUNDRY_PROFILE=core forge test -vv --mc DynamicKinkModelV1Test
contract DynamicKinkModelV1Test is RcompTestDynamicKink, RcurTestDynamicKink {
    uint256 constant TODAY = 1682885514;
    DynamicKinkModelV1 immutable INTEREST_RATE_MODEL;

    int256 constant DP = 10 ** 18;

    constructor() {
        INTEREST_RATE_MODEL = new DynamicKinkModelV1();
    }

    function test_rcur() public {
        RcurData[] memory data = _readDataFromJsonRcur();

        for (uint i; i < data.length; i++) {
            (IDynamicKinkModelV1.Setup memory setup, DebugRcur memory debug) = _toSetupRcur(data[i]);
            emit log_string("******");
            _printRcur(data[i]);

            (int256 rcur, int256 k , int256 r) = INTEREST_RATE_MODEL.currentInterestRate(
                setup,
                data[i].input.lastTransactionTime,
                data[i].input.currentTime,
                data[i].input.lastUtilization
            );

            emit log_named_int("return: rcur", rcur);
            emit log_named_int("return: k", k);
            emit log_named_int("expected: rcur", data[i].expected.currentAnnualInterest);
            emit log_named_uint("id", data[i].id);
            emit log_named_int("relative error for rcur in 10^18 bp new/expected", relativeCheck(rcur, data[i].expected.currentAnnualInterest));
            emit log_named_int("relative error for k in 10^18 bp new/expected", relativeCheck(k, data[i].debug.k));
            emit log_named_int("relative error for r in 10^18 bp new/expected", relativeCheck(r, data[i].debug.r));
            emit log_string("******\n\n\n\n");
        }

        assertEq(INTEREST_RATE_MODEL.DECIMALS(), 18);
    }

    function relativeCheck(int256 a, int256 b) internal returns (int256) {
        if (b != 0) {
            return a * DP / b;
        } else {
            return a == b ? DP : int256(0);
        }
    }

    function test_rcomp() public {
        RcompData[] memory data = _readDataFromJsonRcomp();

        for (uint i; i < data.length; i++) {
            (IDynamicKinkModelV1.Setup memory setup, DebugRcomp memory debug) = _toSetupRcomp(data[i]);
            emit log_string("******");
            _printRcomp(data[i]);

            (int256 rcomp, int256 k, int256 x, bool didOverflow) = INTEREST_RATE_MODEL.compoundInterestRate(
                setup,
                data[i].input.lastTransactionTime,
                data[i].input.currentTime,
                data[i].input.lastUtilization
            );

            emit log_named_int("return: rcomp", rcomp);
            emit log_named_int("return: k", k);
            emit log_named_int("return: x", x);
            emit log_string(string.concat("return: didOverflow: ", (didOverflow ? "true" : "false")));
            emit log_named_int("expected: rcomp", data[i].expected.compoundInterest);
            emit log_named_int("expected: k", data[i].expected.newSlope);
            emit log_string(string.concat("expected: didOverflow ", (data[i].expected.didOverflow == 1 ? "true" : "false")));
            emit log_named_int("expected (debug): x", data[i].debug.x);

            if (data[i].expected.didOverflow == 0) {
                emit log_named_int("relative error for rcomp in 10^18 bp new/expected", rcomp * DP / data[i].expected.compoundInterest);
                emit log_named_int("relative error for k in 10^18 bp new/expected", k * DP / data[i].expected.newSlope);
                emit log_named_int("relative error for x in 10^18 bp new/expected", x * DP / data[i].debug.x);
            } else {
                emit log_string(
                    didOverflow == (data[i].expected.didOverflow == 1) ?
                    "relative error for didOverflow 0%" :
                    "relative error for didOverflow 100% mismatch"
                );
            }
            emit log_string("******\n\n\n\n");
        }

        assertEq(INTEREST_RATE_MODEL.DECIMALS(), 18);
    }
}
