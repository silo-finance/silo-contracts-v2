// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";

import {DynamicKinkModel, IDynamicKinkModel} from "../../../../contracts/interestRateModel/kink/DynamicKinkModel.sol";
import {DynamicKinkModelConfig} from "../../../../contracts/interestRateModel/kink/DynamicKinkModelConfig.sol";

import {RcompDynamicKinkTestData} from "../../data-readers/RcompDynamicKinkTestData.sol";
import {RcurDynamicKinkTestData} from "../../data-readers/RcurDynamicKinkTestData.sol";

import {ISilo} from "../../../../contracts/interfaces/ISilo.sol";

contract DynamicKinkModelMock is DynamicKinkModel {
    function mockState(IDynamicKinkModel.Config memory _c, int256 _u, int256 _k) external {
        irmConfig = new DynamicKinkModelConfig(_c);
        modelState.u = SafeCast.toInt96(_u);
        modelState.k = _k;
    }
}

/* 
FOUNDRY_PROFILE=core_test forge test -vv --mc DynamicKinkModelTest
*/
contract DynamicKinkModelTest is RcompDynamicKinkTestData, RcurDynamicKinkTestData {
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
        _rcurDiffPercent[1] = 1659788986;
        _rcurDiffPercent[28] = 12614396211;


        _rcompDiffPercent[3] = 11344832805;
        _rcompDiffPercent[4] = 2413470567276;
        _rcompDiffPercent[9] = 13912472470161;
        _rcompDiffPercent[10] = 2908788205437;
        _rcompDiffPercent[12] = 13561192345247;
        _rcompDiffPercent[13] = 20115935527;
        _rcompDiffPercent[15] = 1468613269084;
        _rcompDiffPercent[29] = 18428002065;
    }

    /* 
    FOUNDRY_PROFILE=core_test forge test -vv --mt test_kink_verifyConfig_empty
    */
    function test_kink_verifyConfig_empty() public view {
        IDynamicKinkModel.Config memory c;

        IRM.verifyConfig(c);
    }

    /* 
    FOUNDRY_PROFILE=core_test forge test -vv --mt test_kink_verifyConfig_errors
    */
    function test_kink_verifyConfig_errors() public {
        IDynamicKinkModel.Config memory c;

        // 0 <= ulow <= u1 <= u2 <= ucrit <= DP
        // require(_config.ulow.isBetween(0, _config.u1), InvalidUlow());
        c.ulow = 10;
        vm.expectRevert(IDynamicKinkModel.InvalidUlow.selector);
        IRM.verifyConfig(c);

        // require(_config.u1.isBetween(_config.ulow, _config.u2), InvalidU1());
        c.u1 = 20;
        vm.expectRevert(IDynamicKinkModel.InvalidU1.selector);
        IRM.verifyConfig(c);

        // require(_config.u2.isBetween(_config.u1, _config.ucrit), InvalidU2());
        c.u2 = 30;
        vm.expectRevert(IDynamicKinkModel.InvalidU2.selector);
        IRM.verifyConfig(c);

        // require(_config.ucrit.isBetween(_config.u2, _DP), InvalidUcrit());
        c.ucrit = _DP + 1;
        vm.expectRevert(IDynamicKinkModel.InvalidUcrit.selector);
        IRM.verifyConfig(c);
        
        c.ucrit = _DP;
        IRM.verifyConfig(c);

        // require(_config.rmin.isBetween(0, _DP), InvalidRmin());

        // require(_config.kmin.isBetween(0, UNIVERSAL_LIMIT), InvalidKmin());
        // require(_config.kmax.isBetween(_config.kmin, UNIVERSAL_LIMIT), InvalidKmax());

        // require(_config.alpha.isBetween(0, UNIVERSAL_LIMIT), InvalidAlpha());

        // require(_config.cminus.isBetween(0, UNIVERSAL_LIMIT), InvalidCminus());
        // require(_config.cplus.isBetween(0, UNIVERSAL_LIMIT), InvalidCplus());

        // require(_config.c1.isBetween(0, UNIVERSAL_LIMIT), InvalidC1());
        // require(_config.c2.isBetween(0, UNIVERSAL_LIMIT), InvalidC2());

        // // TODO do we still need upper limit?
        // require(_config.dmax.isBetween(_config.c2, UNIVERSAL_LIMIT), InvalidDmax());

        // pass
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
                assertTrue(data[i].expected.didOverflow == 1, "didOverflow");
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
            IRM.mockState(c, data[i].input.lastUtilization, state.k);

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

            (int256 rcomp, int256 k) = IRM.compoundInterestRate(
                c,
                state,
                data[i].input.lastTransactionTime,
                data[i].input.currentTime,
                data[i].input.lastUtilization,
                data[i].input.totalBorrowAmount
            );

            if (data[i].input.totalBorrowAmount == 0) {
                assertEq(rcomp, 0, "[compoundInterestRate] when no debt we always return early");
                continue;
            }

            uint256 acceptableDiffPercent = _getAcceptableDiffPercent(data[i].id, _rcompDiffPercent);

            _assertCloseTo(rcomp, data[i].expected.compoundInterest, data[i].id, "rcomp is not close to expected value", acceptableDiffPercent);
            _assertCloseTo(k, data[i].expected.newSlope, data[i].id, "k is not close to expected value");

            if (data[i].expected.didOverflow == 1) {
                assertEq(rcomp, 0, "didOverflow expecte 0 result");
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
            IRM.mockState(c, data[i].input.lastUtilization, state.k);

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
