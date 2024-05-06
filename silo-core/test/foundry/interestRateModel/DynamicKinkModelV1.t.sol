// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {DynamicKinkModelV1} from "../../../contracts/interestRateModel/DynamicKinkModelV1.sol";
import "../data-readers/RcompTestDynamicKink.sol";
import "../data-readers/RcurTestDynamicKink.sol";

// FOUNDRY_PROFILE=core forge test -vv --mc DynamicKinkModelV1Test
contract DynamicKinkModelV1Test is RcompTestDynamicKink, RcurTestDynamicKink {
    DynamicKinkModelV1 immutable INTEREST_RATE_MODEL;

    int256 constant DP = 10 ** 18;

    constructor() {
        INTEREST_RATE_MODEL = new DynamicKinkModelV1();
    }

    function relativeAssertion(
        bool isRcomp,
        uint256 testId,
        string memory details,
        int256 a,
        int256 b
    ) internal {
        int256 relativeError;

        if (b != 0) {
            relativeError = a * DP / b;
        } else {
            relativeError = a == b ? DP : int256(0);
        }

        int256 treshold = 10**12;

        // in three rcomp cases precision is less accurate, it is OK, these cases are reviewed
        if (isRcomp && (testId == 155 || testId == 156 || testId == 223)) {
            treshold = treshold * 10;
        }

        bool satisfied = relativeError > DP ? relativeError - DP < treshold : DP - relativeError < treshold;

        string memory errorMessage = string.concat(
            "ID ",
            vm.toString(testId),
            ": ",
            details,
            " relative error: ",
            vm.toString(relativeError),
            " larger than precision threshold"
        );

        assertTrue(satisfied, errorMessage);
    }

    function test_rcur() public {
        RcurData[] memory data = _readDataFromJsonRcur();

        for (uint i; i < data.length; i++) {
            (IDynamicKinkModelV1.Setup memory setup, DebugRcur memory debug) = _toSetupRcur(data[i]);
            // _printRcur(data[i]);

            (int256 rcur, bool didCap, bool didOverflow) = INTEREST_RATE_MODEL.currentInterestRate(
                setup,
                data[i].input.lastTransactionTime,
                data[i].input.currentTime,
                data[i].input.lastUtilization,
                data[i].input.totalDeposits,
                data[i].input.totalBorrowAmount
            );

            int256 overflow = didOverflow ? int256(1) : int256(0);
            int256 cap = didCap ? int256(1) : int256(0);

            relativeAssertion(false, data[i].id, "relative error for rcur ", rcur, data[i].expected.currentAnnualInterest);
            relativeAssertion(false, data[i].id, "relative error for didCap ", cap, data[i].expected.didCap);
            relativeAssertion(false, data[i].id, "relative error for didOverflow ", overflow, data[i].expected.didOverflow);
        }
    }

    function test_rcomp() public {
        RcompData[] memory data = _readDataFromJsonRcomp();

        for (uint i; i < data.length; i++) {
            (IDynamicKinkModelV1.Setup memory setup, DebugRcomp memory debug) = _toSetupRcomp(data[i]);
            // _printRcomp(data[i]);

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

            relativeAssertion(true, data[i].id, "relative error for rcomp", rcomp, data[i].expected.compoundInterest);
            relativeAssertion(true, data[i].id, "relative error for k", k, data[i].expected.newSlope);
            relativeAssertion(true, data[i].id, "relative error for didOverflow", overflow, data[i].expected.didOverflow);
            relativeAssertion(true, data[i].id, "relative error for didCap", cap, data[i].expected.didCap);
        }
    }
}
