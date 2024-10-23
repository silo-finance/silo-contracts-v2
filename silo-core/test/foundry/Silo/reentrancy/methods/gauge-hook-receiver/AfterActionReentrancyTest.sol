// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IGaugeHookReceiver} from "silo-core/contracts/interfaces/IGaugeHookReceiver.sol";
import {TestStateLib} from "../../TestState.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";

contract AfterActionReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will revert (permissions check)");
        _ensureItWillRevert();
    }

    function verifyReentrancy() external {
        _ensureItWillRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "afterAction(address,uint256,bytes)";
    }

    function _ensureItWillRevert() internal {
        address hookReceiver = TestStateLib.hookReceiver();

        vm.expectRevert(IGaugeHookReceiver.GaugeIsNotConfigured.selector);
        IGaugeHookReceiver(hookReceiver).afterAction(address(this), 0, "");
    }
}
