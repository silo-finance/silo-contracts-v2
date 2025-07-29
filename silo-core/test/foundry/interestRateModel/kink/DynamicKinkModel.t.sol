// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {DynamicKinkModel, IDynamicKinkModel} from "../../../../contracts/interestRateModel/kink/DynamicKinkModel.sol";
import {RcompDynamicKinkTestData} from "../../data-readers/RcompDynamicKinkTestData.sol";
import {RcurDynamicKinkTestData} from "../../data-readers/RcurDynamicKinkTestData.sol";

/* 
FOUNDRY_PROFILE=core_test forge test -vv --mc DynamicKinkModelTest
*/
contract DynamicKinkModelTest is RcompDynamicKinkTestData, RcurDynamicKinkTestData {
    DynamicKinkModel immutable INTEREST_RATE_MODEL;

    int256 constant _DP = 10 ** 18;

    mapping(uint256 id => uint256 aloowedDiffPercent) private _rcompDiffPercent;
    mapping(uint256 id => uint256 aloowedDiffPercent) private _rcurDiffPercent;

    constructor() {
        INTEREST_RATE_MODEL = new DynamicKinkModel();
    }

    /* 
    FOUNDRY_PROFILE=core_test forge test -vv --mt test_kink_rcur
    */
    function test_kink_rcur() public {
        RcurData[] memory data = _readDataFromJsonRcur();

        // 1e18 is 100%
        _rcurDiffPercent[1] = 1659788986;
        _rcurDiffPercent[28] = 12614396211;

        for (uint i; i < data.length; i++) {
            IDynamicKinkModel.Setup memory setup = _toSetupRcur(data[i]);
            // _printRcur(data[i]);

            (int256 rcur, bool didOverflow, bool didCap) = INTEREST_RATE_MODEL.currentInterestRate(
                setup,
                data[i].input.lastTransactionTime,
                data[i].input.currentTime,
                data[i].input.lastUtilization,
                data[i].input.totalDeposits,
                data[i].input.totalBorrowAmount
            );

            int256 overflow = didOverflow ? int256(1) : int256(0);
            int256 cap = didCap ? int256(1) : int256(0);

            uint256 _acceptableDiffPercent = _rcurDiffPercent[data[i].id];
            if (_acceptableDiffPercent == 0) {
                _acceptableDiffPercent = 1e10; // default value for tiny differences
            }

            _assertCloseTo(rcur, data[i].expected.currentAnnualInterest, data[i].id, "rcur is not close to expected value", _acceptableDiffPercent);
            _assertCloseTo(overflow, data[i].expected.didOverflow, data[i].id, "didOverflow is not close to expected value");
            _assertCloseTo(cap, data[i].expected.didCap, data[i].id, "didCap is not close to expected value");
        }
    }

    /* 
    FOUNDRY_PROFILE=core_test forge test -vv --mt test_kink_rcomp
    */
    function test_kink_rcomp() public {
        RcompData[] memory data = _readDataFromJsonRcomp();

        _rcompDiffPercent[3] = 11344832805;
        _rcompDiffPercent[4] = 2413470567276;
        _rcompDiffPercent[9] = 13912472470161;
        _rcompDiffPercent[10] = 2908788205437;
        _rcompDiffPercent[12] = 13561192345247;
        _rcompDiffPercent[13] = 20115935527;
        _rcompDiffPercent[15] = 1468613269084;
        _rcompDiffPercent[29] = 18428002065;

        for (uint i; i < data.length; i++) {
            IDynamicKinkModel.Setup memory setup = _toSetupRcomp(data[i]);
            // _printRcomp(data[i]);

            (int256 rcomp, int256 k, bool didOverflow, bool didCap) = INTEREST_RATE_MODEL.compoundInterestRate(
                setup,
                data[i].input.lastTransactionTime,
                data[i].input.currentTime,
                data[i].input.lastUtilization,
                data[i].input.totalDeposits,
                data[i].input.totalBorrowAmount
            );

            int256 overflow = didOverflow ? int256(1) : int256(0);
            int256 cap = didCap ? int256(1) : int256(0);

            uint256 _acceptableDiffPercent = _rcompDiffPercent[data[i].id];
            if (_acceptableDiffPercent == 0) {
                _acceptableDiffPercent = 0.00000001e18; // default value for tiny differences
            }

            // TODO isn't that too much precision?
            _assertCloseTo(rcomp, data[i].expected.compoundInterest, data[i].id, "rcomp is not close to expected value", _acceptableDiffPercent);
            _assertCloseTo(k, data[i].expected.newSlope, data[i].id, "k is not close to expected value");
            _assertCloseTo(overflow, data[i].expected.didOverflow, data[i].id, "didOverflow is not close to expected value");
            _assertCloseTo(cap, data[i].expected.didCap, data[i].id, "didCap is not close to expected value");
        }
    }

    /* 
    FOUNDRY_PROFILE=core_test forge test -vv --mt test_kink_AMT_MAX
    */
    function test_kink_AMT_MAX() public view {
        int256 amtMax = INTEREST_RATE_MODEL.AMT_MAX();
        assertEq(uint256(amtMax), type(uint256).max / uint256(2 ** 16 * 1e18), "AMT_MAX is not correct");
    }

    function _assertCloseTo(
        int256 _got,
        int256 _expected,
        uint256 _testId,
        string memory _msg
    ) internal pure {
        _assertCloseTo(_got, _expected, _testId, _msg, 0);
    }

    function _assertCloseTo(
        int256 _got,
        int256 _expected,
        uint256 _testId,
        string memory _msg,
        uint256 _acceptableDiffPercent
    ) internal pure {
        if (_got == _expected) {
            return; // no need to check further
        }

        int256 diffPercent = _expected == 0 ? _DP : (_got - _expected) * _DP / _expected; // 18 decimal points
        
        if (diffPercent < 0) {
            diffPercent = -diffPercent; // absolute value
        }

        bool satisfied = diffPercent <= int256(_acceptableDiffPercent);

        string memory errorMessage = string.concat(
            "ID ",
            vm.toString(_testId),
            ": ",
            _msg,
            " relative error: ",
            vm.toString(diffPercent),
            " [%] larger than acceptable diff: ",
            vm.toString(_acceptableDiffPercent)
        );

        if (!satisfied) {
            console2.log("     got", _got);
            console2.log("expected", _expected);
            console2.log("           diff %", diffPercent);
            console2.log("acceptable diff %", _acceptableDiffPercent);
        }

        assertTrue(satisfied, errorMessage);
    }
}
