// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";

import {DynamicKinkModel, IDynamicKinkModel} from "../../../../contracts/interestRateModel/kink/DynamicKinkModel.sol";
import {DynamicKinkModelConfig} from "../../../../contracts/interestRateModel/kink/DynamicKinkModelConfig.sol";

import {KinkRcompTestData} from "../../data-readers/KinkRcompTestData.sol";
import {KinkRcurTestData} from "../../data-readers/KinkRcurTestData.sol";

import {ISilo} from "../../../../contracts/interfaces/ISilo.sol";

contract DynamicKinkModelMock is DynamicKinkModel {
    function mockState(IDynamicKinkModel.Config memory _c, int96 _k) external {
        irmConfig = new DynamicKinkModelConfig(_c);
        modelState.k = _k;
    }
}

/* 
FOUNDRY_PROFILE=core_test forge test -vv --mc DynamicKinkModelJsonTest
*/
contract DynamicKinkModelJsonTest is KinkRcompTestData, KinkRcurTestData {
    DynamicKinkModelMock immutable IRM;

    int256 constant _DP = 10 ** 18;

    mapping(uint256 id => uint256 aloowedDiffPercent) private _rcompDiffPercent;
    mapping(uint256 id => uint256 aloowedDiffPercent) private _rcurDiffPercent;

    ISilo.UtilizationData public utilizationData;

    constructor() {
        IDynamicKinkModel.Config memory cfg;
        
        IRM = new DynamicKinkModelMock();
        IRM.initialize(cfg, address(this), address(this));

        // 1e18 is 100%
        _rcurDiffPercent[259] = 11075646641;
        _rcurDiffPercent[281] = 195011203199;
        _rcurDiffPercent[285] = 18894769892;
        _rcurDiffPercent[289] = 23071444669;

        _rcompDiffPercent[19] = 22872736801;
        _rcompDiffPercent[28] = 12374540229;
        _rcompDiffPercent[43] = 19274329796;
        _rcompDiffPercent[44] = 168883855185;
        _rcompDiffPercent[50] = 13846907445;
        _rcompDiffPercent[51] = 10855909671;
        _rcompDiffPercent[54] = 35914205060;
        _rcompDiffPercent[62] = 10519955101;
        _rcompDiffPercent[71] = 45445460982;
        _rcompDiffPercent[74] = 15544865743;
        _rcompDiffPercent[98] = 26976031665;
        _rcompDiffPercent[114] = 12081262091;
        _rcompDiffPercent[115] = 84615802266;
        _rcompDiffPercent[140] = 29832348581;
        _rcompDiffPercent[166] = 76697467726;
        _rcompDiffPercent[169] = 12756017220;
        _rcompDiffPercent[194] = 32667389684;
        _rcompDiffPercent[197] = 63694885413;
        _rcompDiffPercent[231] = 32481920192;
        _rcompDiffPercent[294] = 14946966269;
        _rcompDiffPercent[299] = 11559641605;
    }

    /* 
    FOUNDRY_PROFILE=core_test forge test -vv --mt test_kink_verifyConfig_empty
    */
    function test_kink_verifyConfig_empty() public view {
        IDynamicKinkModel.Config memory c;

        IRM.verifyConfig(c);
    }

    /* 
    FOUNDRY_PROFILE=core_test forge test -vv --mt test_kink_rcur_json
    */
    function test_kink_rcur_json() public view {
        RcurData[] memory data = _readDataFromJsonRcur();

        for (uint i; i < data.length; i++) {
            (IDynamicKinkModel.ModelState memory state, IDynamicKinkModel.Config memory c) = _toSetupRcur(data[i]);
            // _printRcur(data[i]);

            try IRM.currentInterestRate(
                c,
                state,
                data[i].input.lastTransactionTime,
                data[i].input.currentTime,
                data[i].input.lastUtilization,
                data[i].input.totalBorrowAmount
            ) returns (int256 rcur) {
                if (data[i].input.totalBorrowAmount == 0) {
                    assertEq(rcur, 0, "when no debt we always return early");
                    continue;
                }

                uint256 acceptableDiffPercent = _getAcceptableDiffPercent(data[i].id, _rcurDiffPercent);

                _assertCloseTo(rcur, data[i].expected.currentAnnualInterest, data[i].id, "rcur is not close to expected value", acceptableDiffPercent);
            } catch {
                revert(string.concat("we should not revert in this tests, but case with ID ", vm.toString(data[i].id), " did"));
            }
        }
    }

    /* 
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_currentInterestRate_json -vv
    */
    function test_kink_currentInterestRate_json() public {
        RcurData[] memory data = _readDataFromJsonRcur();

        address silo = address(this);

        for (uint i; i < data.length; i++) {
            (IDynamicKinkModel.ModelState memory state, IDynamicKinkModel.Config memory c) = _toSetupRcur(data[i]);

            vm.warp(uint256(data[i].input.currentTime));
            _setUtilizationData(data[i]);
            IRM.mockState(c, state.k);

            // _printRcur(data[i]);

            uint256 rcur = IRM.getCurrentInterestRate(silo, uint256(data[i].input.currentTime));

            if (data[i].input.totalBorrowAmount == 0) {
                assertEq(rcur, 0, "[getCurrentInterestRate] when no debt we always return early");
                continue;
            }

            uint256 acceptableDiffPercent = _getAcceptableDiffPercent(data[i].id, _rcurDiffPercent);

            _assertCloseTo(
                SafeCast.toInt256(rcur),
                data[i].expected.currentAnnualInterest,
                data[i].id, 
                "[getCurrentInterestRate] rcur is not close to expected value", acceptableDiffPercent
            );
        }
    }

    /* 
    FOUNDRY_PROFILE=core_test forge test -vv --mt test_kink_rcomp_json
    */
    function test_kink_rcomp_json() public view {
        RcompData[] memory data = _readDataFromJsonRcomp();

        for (uint i; i < data.length; i++) {
            (IDynamicKinkModel.ModelState memory state, IDynamicKinkModel.Config memory c) = _toSetupRcomp(data[i]);
            // _printRcomp(data[i]);

            try IRM.compoundInterestRate(
                c,
                state,
                data[i].input.lastTransactionTime,
                data[i].input.currentTime,
                data[i].input.lastUtilization,
                data[i].input.totalBorrowAmount
            ) returns (int256 rcomp, int256 k) {
                if (data[i].input.totalBorrowAmount == 0) {
                    assertEq(rcomp, 0, "[compoundInterestRate] when no debt we always return early");
                    continue;
                }

                uint256 acceptableDiffPercent = _getAcceptableDiffPercent(data[i].id, _rcompDiffPercent);

                _assertCloseTo(rcomp, data[i].expected.compoundInterest, data[i].id, "rcomp is not close to expected value", acceptableDiffPercent);
                _assertCloseTo(k, data[i].expected.newSlope, data[i].id, "k is not close to expected value");

                assertEq(data[i].expected.didOverflow, 0, "didOverflow expect overflow");
                
            } catch {
                assertEq(
                    data[i].expected.didOverflow, 
                    1, 
                    string.concat("we should not revert in this tests, but case with ID ", vm.toString(data[i].id), " did")
                );
            }
        }
    }

    /* 
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_getCompoundInterestRate_json -vv 
    */
    function test_kink_getCompoundInterestRate_json() public {
        RcompData[] memory data = _readDataFromJsonRcomp();

        address silo = address(this);

        for (uint i; i < data.length; i++) {
            (IDynamicKinkModel.ModelState memory state, IDynamicKinkModel.Config memory c) = _toSetupRcomp(data[i]);

            vm.warp(uint256(data[i].input.currentTime));
            _setUtilizationData(data[i]);
            IRM.mockState(c, state.k);

            // _printRcomp(data[i]);

            uint256 rcomp = IRM.getCompoundInterestRate(silo, uint256(data[i].input.currentTime));

            if (data[i].input.totalBorrowAmount == 0) {
                assertEq(rcomp, 0, "[getCompoundInterestRate] when no debt we always return early");
                continue;
            }

            uint256 acceptableDiffPercent = _getAcceptableDiffPercent(data[i].id, _rcompDiffPercent);

            _assertCloseTo(
                SafeCast.toInt256(rcomp), 
                data[i].expected.compoundInterest, 
                data[i].id, 
                "[getCompoundInterestRate] rcomp is not close to expected value", 
                acceptableDiffPercent
            );
        }
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

    function _setUtilizationData(RcompData memory _data) internal {
        utilizationData = ISilo.UtilizationData({
            collateralAssets: SafeCast.toUint256(_data.input.totalDeposits),
            debtAssets: SafeCast.toUint256(_data.input.totalBorrowAmount),
            interestRateTimestamp: SafeCast.toUint64(SafeCast.toUint256(_data.input.lastTransactionTime))
        });
    }

    function _setUtilizationData(RcurData memory _data) internal {
        utilizationData = ISilo.UtilizationData({
            collateralAssets: SafeCast.toUint256(_data.input.totalDeposits),
            debtAssets: SafeCast.toUint256(_data.input.totalBorrowAmount),
            interestRateTimestamp: SafeCast.toUint64(SafeCast.toUint256(_data.input.lastTransactionTime))
        });
    }

    function _getAcceptableDiffPercent(uint256 _id, mapping(uint256 => uint256) storage _diffs) 
        internal 
        view
        returns (uint256 acceptableDiffPercent) 
    {
        acceptableDiffPercent = _diffs[_id];

        if (acceptableDiffPercent == 0) {
            acceptableDiffPercent = 1e10; // default value for tiny differences
        }
    }
}
