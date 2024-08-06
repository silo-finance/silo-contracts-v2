// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract SiloDataStorageReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external view {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "siloData()";
    }

    function _ensureItWillNotRevert() internal view {
        TestStateLib.silo0().siloData();
        TestStateLib.silo1().siloData();
    }
}