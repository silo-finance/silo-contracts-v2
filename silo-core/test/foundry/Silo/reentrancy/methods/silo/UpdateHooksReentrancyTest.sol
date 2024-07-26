// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ICrossReentrancyGuard} from "silo-core/contracts/interfaces/ICrossReentrancyGuard.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract UpdateHooksReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");

        TestStateLib.silo0().updateHooks();
        TestStateLib.silo1().updateHooks();
    }

    function verifyReentrancy() external {
        vm.expectRevert(ICrossReentrancyGuard.CrossReentrantCall.selector);
        TestStateLib.silo0().updateHooks();

        vm.expectRevert(ICrossReentrancyGuard.CrossReentrantCall.selector);
        TestStateLib.silo1().updateHooks();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "updateHooks()";
    }
}
