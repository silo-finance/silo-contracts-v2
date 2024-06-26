// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract WithdrawFeesReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tRevert as expected");
        _revertAsExpected();
    }

    function verifyReentrancy() external {
        _revertAsExpected();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "withdrawFees()";
    }

    function _revertAsExpected() internal {
        ISilo silo0 = TestStateLib.silo0();
        ISilo silo1 = TestStateLib.silo1();

        vm.expectRevert(ISilo.EarnedZero.selector);
        silo0.withdrawFees();

        vm.expectRevert(ISilo.EarnedZero.selector);
        silo1.withdrawFees();
    }
}
