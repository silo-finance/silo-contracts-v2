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
    function mockU(address _silo, int256 _u) external {
        _getSetup[_silo].u = SafeCast.toInt232(_u);
    }

    function mockK(address _silo, int256 _k) external {
        _getSetup[_silo].k = SafeCast.toInt232(_k);
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
        IRM.initialize(address(new DynamicKinkModelConfig(cfg)), address(this));

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
    FOUNDRY_PROFILE=core_test forge test -vv --mt test_kink_rcur_json
    */
    function test_kink_rcur_json() public view {
        RcurData[] memory data = _readDataFromJsonRcur();

        for (uint i; i < data.length; i++) {
            IDynamicKinkModel.Setup memory setup = _toSetupRcur(data[i]);
            // _printRcur(data[i]);

            (int256 rcur, bool didOverflow, bool didCap) = IRM.currentInterestRate(
                setup,
                data[i].input.lastTransactionTime,
                data[i].input.currentTime,
                data[i].input.lastUtilization,
                data[i].input.totalDeposits,
                data[i].input.totalBorrowAmount
            );

            if (data[i].input.totalBorrowAmount == 0) {
                assertEq(rcur, 0, "when no debt we always return early");
                continue;
            }

            int256 overflow = didOverflow ? int256(1) : int256(0);
            int256 cap = didCap ? int256(1) : int256(0);

            uint256 acceptableDiffPercent = _getAcceptableDiffPercent(data[i].id, _rcurDiffPercent);

            _assertCloseTo(rcur, data[i].expected.currentAnnualInterest, data[i].id, "rcur is not close to expected value", acceptableDiffPercent);
            _assertCloseTo(overflow, data[i].expected.didOverflow, data[i].id, "didOverflow is not close to expected value");
            _assertCloseTo(cap, data[i].expected.didCap, data[i].id, "didCap is not close to expected value");
        }
    }

    /* 
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_currentInterestRate_json -vv
    */
    function test_kink_currentInterestRate_json() public {
        RcurData[] memory data = _readDataFromJsonRcur();

        address silo = address(this);

        for (uint i; i < data.length; i++) {
            IDynamicKinkModel.Setup memory setup = _toSetupRcur(data[i]);

            vm.warp(uint256(data[i].input.currentTime));
            _setUtilizationData(data[i]);
            IRM.updateSetup(ISilo(silo), setup.config, setup.config.kmin); // note, we using kmin instead of k
            IRM.mockU(silo, data[i].input.lastUtilization);
            IRM.mockK(silo, setup.k);

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
            IDynamicKinkModel.Setup memory setup = _toSetupRcomp(data[i]);
            // _printRcomp(data[i]);

            (int256 rcomp, int256 k, bool didOverflow, bool didCap) = IRM.compoundInterestRate(
                setup,
                data[i].input.lastTransactionTime,
                data[i].input.currentTime,
                data[i].input.lastUtilization,
                data[i].input.totalDeposits,
                data[i].input.totalBorrowAmount
            );

            if (data[i].input.totalBorrowAmount == 0) {
                assertEq(rcomp, 0, "[compoundInterestRate] when no debt we always return early");
                continue;
            }

            int256 overflow = didOverflow ? int256(1) : int256(0);
            int256 cap = didCap ? int256(1) : int256(0);

            uint256 acceptableDiffPercent = _getAcceptableDiffPercent(data[i].id, _rcompDiffPercent);

            _assertCloseTo(rcomp, data[i].expected.compoundInterest, data[i].id, "rcomp is not close to expected value", acceptableDiffPercent);
            _assertCloseTo(k, data[i].expected.newSlope, data[i].id, "k is not close to expected value");
            _assertCloseTo(overflow, data[i].expected.didOverflow, data[i].id, "didOverflow is not close to expected value");
            _assertCloseTo(cap, data[i].expected.didCap, data[i].id, "didCap is not close to expected value");
        }
    }

    /* 
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_getCompoundInterestRate_json -vv 
    */
    function test_kink_getCompoundInterestRate_json() public {
        RcompData[] memory data = _readDataFromJsonRcomp();

        address silo = address(this);

        for (uint i; i < data.length; i++) {
            IDynamicKinkModel.Setup memory setup = _toSetupRcomp(data[i]);

            vm.warp(uint256(data[i].input.currentTime));
            _setUtilizationData(data[i]);
            IRM.updateSetup(ISilo(silo), setup.config, setup.config.kmin); // note, we using kmin instead of k
            IRM.mockU(silo, data[i].input.lastUtilization);
            IRM.mockK(silo, setup.k);

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

    /* 
    FOUNDRY_PROFILE=core_test forge test -vv --mt test_kink_AMT_MAX
    */
    function test_kink_AMT_MAX() public view {
        int256 amtMax = IRM.AMT_MAX();
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
