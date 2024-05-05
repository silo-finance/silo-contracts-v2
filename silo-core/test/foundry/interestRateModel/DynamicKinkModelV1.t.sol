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
            if (i != 95) {
                continue;
            }

            (IDynamicKinkModelV1.Setup memory setup, DebugRcur memory debug) = _toSetupRcur(data[i]);
            emit log_string("******");
            _printRcur(data[i]);

            (int256 rcur, int256 k , int256 r, bool didCap, bool didOverflow) = INTEREST_RATE_MODEL.currentInterestRate(
                setup,
                data[i].input.lastTransactionTime,
                data[i].input.currentTime,
                data[i].input.lastUtilization,
                data[i].input.totalDeposits,
                data[i].input.totalBorrowAmount
            );

            int256 overflow = didOverflow ? int256(1) : int256(0);
            int256 cap = didCap ? int256(1) : int256(0);

            emit log_named_int("return: rcur", rcur);
            emit log_named_int("return: k", k);
            emit log_named_int("return: r", r);
            emit log_named_int("return: didCap", cap);
            emit log_named_int("return: didOverflow", overflow);

            emit log_named_int("expected: rcur", data[i].expected.currentAnnualInterest);
            emit log_named_uint("id", data[i].id);
            relativeCheck(data[i].id, "relative error for rcur in 10^18 bp new/expected", rcur, data[i].expected.currentAnnualInterest);
            relativeCheck(data[i].id, "relative error for k in 10^18 bp new/expected", k, data[i].debug.k);
            relativeCheck(data[i].id, "relative error for r in 10^18 bp new/expected",r, data[i].debug.r);
            relativeCheck(data[i].id, "relative error for didOverflow in 10^18 bp new/expected", overflow, data[i].expected.didOverflow);
            relativeCheck(data[i].id, "relative error for didCap in 10^18 bp new/expected", cap, data[i].expected.didCap);
            emit log_string("******\n\n\n\n");
        }

        assertEq(INTEREST_RATE_MODEL.DECIMALS(), 18);
    }

    function relativeCheck(uint256 testId, string memory message, int256 a, int256 b) internal {
        int256 relativeError;
        if (b != 0) {
            relativeError = a * DP / b;
        } else {
            relativeError = a == b ? DP : int256(0);
        }

        int256 treshold = 10**12;
        bool logBigError = relativeError > DP ? relativeError - DP > treshold : DP - relativeError > treshold;

        if (logBigError) {
            emit log_named_uint("big error at id:", testId);
        }

        emit log_named_int(message, relativeError);
    }

    function test_rcomp() public {
        RcompData[] memory data = _readDataFromJsonRcomp();

        for (uint i; i < data.length; i++) {
            if (i != 84) {
                continue;
            }
            (IDynamicKinkModelV1.Setup memory setup, DebugRcomp memory debug) = _toSetupRcomp(data[i]);
            emit log_string("******");
            _printRcomp(data[i]);

            (int256 rcomp, int256 k, bool didCap, bool didOverflow) = INTEREST_RATE_MODEL.compoundInterestRate(
                setup,
                data[i].input.lastTransactionTime,
                data[i].input.currentTime,
                data[i].input.lastUtilization,
                data[i].input.totalDeposits,
                data[i].input.totalBorrowAmount
            );

            int256 overflow = didOverflow ? int256(1) : int256(0);
            int256 cap = didCap ? int256(1) : int256(0);

            emit log_named_int("return: rcomp", rcomp);
            emit log_named_int("return: k", k);
            emit log_string(string.concat("return: didOverflow: ", (didOverflow ? "true" : "false")));
            emit log_string(string.concat("return: didCap: ", (didCap ? "true" : "false")));

            emit log_named_int("expected: rcomp", data[i].expected.compoundInterest);
            emit log_named_int("expected: k", data[i].expected.newSlope);
            emit log_string(string.concat("expected: didOverflow ", (data[i].expected.didOverflow == 1 ? "true" : "false")));
            emit log_string(string.concat("expected: didCap ", (data[i].expected.didCap == 1 ? "true" : "false")));
            // emit log_named_int("expected (debug): x", data[i].debug.x);

            relativeCheck(data[i].id, "relative error for rcomp in 10^18 bp new/expected", rcomp, data[i].expected.compoundInterest);
            relativeCheck(data[i].id, "relative error for k in 10^18 bp new/expected", k, data[i].expected.newSlope);
            relativeCheck(data[i].id, "relative error for didOverflow in 10^18 bp new/expected", overflow, data[i].expected.didOverflow);
            relativeCheck(data[i].id, "relative error for didCap in 10^18 bp new/expected", cap, data[i].expected.didCap);
            
            emit log_string("******\n\n\n\n");
        }

        assertEq(INTEREST_RATE_MODEL.DECIMALS(), 18);
    }
}
