// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";
import {TestStateLib} from "../../TestState.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";

contract AfterActionReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will revert (permissions check)");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "afterAction(address,uint256,bytes)";
    }

    function _ensureItWillNotRevert() internal {
        address hookReceiver = TestStateLib.hookReceiver();
        IHookReceiver(hookReceiver).afterAction(address(this), 0, "");
    }
}
