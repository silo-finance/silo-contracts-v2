// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IIncentiveHook} from "silo-core/contracts/interfaces/IIncentiveHook.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {TestStateLib} from "../../TestState.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";

contract GetIncentivesClaimingLogicsReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external view {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "getIncentivesClaimingLogics(address)";
    }

    function _ensureItWillNotRevert() internal view {
        address hookReceiver = TestStateLib.hookReceiver();
        IIncentiveHook(hookReceiver).getIncentivesClaimingLogics(ISilo(address(this)));
    }
}
