// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract UpdateHooksReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "updateHooks()";
    }

    function _ensureItWillNotRevert() internal {
        TestStateLib.silo0().updateHooks();
        TestStateLib.silo1().updateHooks();
    }
}
