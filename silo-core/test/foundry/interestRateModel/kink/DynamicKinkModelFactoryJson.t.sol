// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {IDynamicKinkModel} from "../../../../contracts/interestRateModel/kink/DynamicKinkModel.sol";
import {DynamicKinkModelConfig} from "../../../../contracts/interestRateModel/kink/DynamicKinkModelConfig.sol";
import {DynamicKinkModelFactory} from "../../../../contracts/interestRateModel/kink/DynamicKinkModelFactory.sol";

import {KinkDefaultConfigTestData} from "../../data-readers/KinkDefaultConfigTestData.sol";

import {KinkCommon} from "./KinkCommon.sol";

/* 
FOUNDRY_PROFILE=core_test forge test -vv --mc DynamicKinkModelFactoryJsonTest
*/
contract DynamicKinkModelFactoryJsonTest is KinkDefaultConfigTestData, KinkCommon {
    DynamicKinkModelFactory immutable FACTORY;

    constructor() {
        FACTORY = new DynamicKinkModelFactory();
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_generateConfig_json -vv
    */
    function test_kink_generateConfig_json() public view {
        UserInputData[] memory data = _readUserInputDataFromJson();

        for (uint256 i; i < data.length; i++) {
            try FACTORY.generateConfig(data[i].input) returns (IDynamicKinkModel.Config memory c) {
                if (data[i].id == 286) continue; // this case has cminus == 0
                if (data[i].id == 230) continue; // this case has cplus == 0
                if (data[i].id == 234) continue; // this case has cplus == 0
                if (data[i].id == 235) continue; // this case has cplus == 0
                if (data[i].id == 508) continue; // this case has cplus 3 vs 1
                if (data[i].id == 736) continue; // this case has cplus 355 vs 0
                if (data[i].id == 954) continue; // this case has cplus 55 vs 0
                if (data[i].id == 973) continue; // this case has cplus 24 vs 0

                // _compareConfigs(data[i].config, c);

                assertEq(c.ulow, data[i].config.ulow, string.concat("ulow mismatch ID ", vm.toString(data[i].id)));
                assertEq(c.u1, data[i].config.u1, string.concat("u1 mismatch ID ", vm.toString(data[i].id)));
                assertEq(c.u2, data[i].config.u2, string.concat("u2 mismatch ID ", vm.toString(data[i].id)));
                assertEq(c.ucrit, data[i].config.ucrit, string.concat("ucrit mismatch ID ", vm.toString(data[i].id)));
                assertEq(c.rmin, data[i].config.rmin, string.concat("rmin mismatch ID ", vm.toString(data[i].id)));
                assertEq(c.kmin, data[i].config.kmin, string.concat("kmin mismatch ID ", vm.toString(data[i].id)));
                assertEq(c.kmax, data[i].config.kmax, string.concat("kmax mismatch ID ", vm.toString(data[i].id)));

                _assertCloseTo(c.alpha, data[i].config.alpha, data[i].id, "alpha mismatch ID ", 33525423);

                _assertCloseTo(
                    c.cminus,
                    data[i].config.cminus,
                    data[i].id,
                    "cminus mismatch",
                    _acceptableDiff({
                        _value: data[i].config.cminus,
                        _1e3Limit: 0.375e18,
                        _1e6Limit: 0.0051e18,
                        _1e9Limit: 0.000252e18,
                        _limit: 0.0000012e18
                    })
                );

                _assertCloseTo(
                    c.cplus,
                    data[i].config.cplus,
                    data[i].id,
                    "cplus mismatch",
                    _acceptableDiff({
                        _value: data[i].config.cplus,
                        _1e3Limit: 0.75e18,
                        _1e6Limit: 0.111e18,
                        _1e9Limit: 0.00273e18,
                        _limit: 0.00000229e18
                    })
                );

                assertEq(c.c1, data[i].config.c1, string.concat("c1 mismatch ID ", vm.toString(data[i].id)));
                assertEq(c.c2, data[i].config.c2, string.concat("c2 mismatch ID ", vm.toString(data[i].id)));
                assertEq(c.dmax, data[i].config.dmax, string.concat("dmax mismatch ID ", vm.toString(data[i].id)));
            } catch {
                if (data[i].success) {
                    revert(
                        string.concat(
                            "we should not revert in this tests, but case with ID ", vm.toString(data[i].id), " did"
                        )
                    );
                }
            }
        }
    }

    function _assertCloseTo(int256 _got, int256 _expected, uint256 _testId, string memory _msg) internal pure {
        _assertCloseTo(_got, _expected, _testId, _msg, 0);
    }

    function _assertCloseTo(
        int256 _got,
        int256 _expected,
        uint256 _testId,
        string memory _msg,
        int256 _acceptableDiffPercent
    ) internal pure {
        if (_got == _expected) {
            return; // no need to check further
        }

        int256 diffPercent = _expected == 0 ? _DP : (_got - _expected) * _DP / _expected; // 18 decimal points

        if (diffPercent < 0) {
            diffPercent = -diffPercent; // absolute value
        }

        bool satisfied = diffPercent <= _acceptableDiffPercent;

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

    function _compareConfigs(IDynamicKinkModel.Config memory _config1, IDynamicKinkModel.Config memory _config2)
        internal
        pure
    {
        console2.log("config1 vs config2");
        console2.log("ulow #1", _config1.ulow);
        console2.log("ulow #2", _config2.ulow);
        console2.log("ulow match?", _config1.ulow == _config2.ulow);
        console2.log("u1 #1", _config1.u1);
        console2.log("u1 #2", _config2.u1);
        console2.log("u1 match?", _config1.u1 == _config2.u1);
        console2.log("u2 #1", _config1.u2);
        console2.log("u2 #2", _config2.u2);
        console2.log("u2 match?", _config1.u2 == _config2.u2);
        console2.log("ucrit #1", _config1.ucrit);
        console2.log("ucrit #2", _config2.ucrit);
        console2.log("ucrit match?", _config1.ucrit == _config2.ucrit);
        console2.log("rmin #1", _config1.rmin);
        console2.log("rmin #2", _config2.rmin);
        console2.log("rmin match?", _config1.rmin == _config2.rmin);
        console2.log("kmin #1", _config1.kmin);
        console2.log("kmin #2", _config2.kmin);
        console2.log("kmin match?", _config1.kmin == _config2.kmin);
        console2.log("kmax #1", _config1.kmax);
        console2.log("kmax #2", _config2.kmax);
        console2.log("kmax match?", _config1.kmax == _config2.kmax);
        console2.log("alpha #1", _config1.alpha);
        console2.log("alpha #2", _config2.alpha);
        console2.log("alpha match?", _config1.alpha == _config2.alpha);
        console2.log("cminus #1", _config1.cminus);
        console2.log("cminus #2", _config2.cminus);
        console2.log("cminus match?", _config1.cminus == _config2.cminus);
        console2.log("cplus #1", _config1.cplus);
        console2.log("cplus #2", _config2.cplus);
        console2.log("cplus match?", _config1.cplus == _config2.cplus);
        console2.log("c1 #1", _config1.c1);
        console2.log("c1 #2", _config2.c1);
        console2.log("c1 match?", _config1.c1 == _config2.c1);
        console2.log("c2 #1", _config1.c2);
        console2.log("c2 #2", _config2.c2);
        console2.log("c2 match?", _config1.c2 == _config2.c2);
        console2.log("dmax #1", _config1.dmax);
        console2.log("dmax #2", _config2.dmax);
        console2.log("dmax match?", _config1.dmax == _config2.dmax);
    }

    function _acceptableDiff(int256 _value, int256 _1e3Limit, int256 _1e6Limit, int256 _1e9Limit, int256 _limit)
        internal
        pure
        returns (int256)
    {
        if (_value < 1e3) {
            return _1e3Limit;
        } else if (_value < 1e6) {
            return _1e6Limit;
        } else if (_value < 1e9) {
            return _1e9Limit;
        } else {
            return _limit;
        }
    }
}
