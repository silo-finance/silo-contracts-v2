// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract UpdateHooksReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");

        TestStateLib.silo0().updateHooks();
        TestStateLib.silo1().updateHooks();
    }

    function verifyReentrancy() external {
        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        TestStateLib.silo0().updateHooks();

        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        TestStateLib.silo1().updateHooks();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "updateHooks()";
    }
}
