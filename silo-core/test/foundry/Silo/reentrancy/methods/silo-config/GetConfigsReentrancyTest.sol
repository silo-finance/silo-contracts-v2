// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract GetConfigsReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external view {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "getConfigs(address,address,uint256)";
    }

    function _ensureItWillNotRevert() internal view {
        address silo0 = address(TestStateLib.silo0());
        address silo1 = address(TestStateLib.silo1());

        TestStateLib.siloConfig().getConfigs(silo0, address(0), 0);
        TestStateLib.siloConfig().getConfigs(silo1, address(0), 0);
    }
}
