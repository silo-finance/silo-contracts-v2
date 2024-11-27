// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ICrossReentrancyGuard} from "silo-core/contracts/interfaces/ICrossReentrancyGuard.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract WithdrawFeesReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tRevert as expected if no fees");
        TestStateLib.silo0().withdrawFees();
    }

    function verifyReentrancy() external {
        vm.expectRevert(ICrossReentrancyGuard.CrossReentrantCall.selector);
        TestStateLib.silo0().withdrawFees();

        vm.expectRevert(ICrossReentrancyGuard.CrossReentrantCall.selector);
        TestStateLib.silo1().withdrawFees();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "withdrawFees()";
    }
}
