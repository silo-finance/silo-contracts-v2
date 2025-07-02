// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Ownable as Ownable1Step} from "openzeppelin5/access/Ownable2Step.sol";

import {Ownable} from "common/access/Ownable.sol";
import {TestStateLib} from "../../TestState.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";

contract TransferOwnership1StepReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will revert");
        _ensureItWillRevert();
    }

    function verifyReentrancy() external {
        _ensureItWillRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "transferOwnership1Step(address)";
    }

    function _ensureItWillRevert() internal {
        address hookReceiver = TestStateLib.hookReceiver();

        vm.expectRevert(abi.encodeWithSelector(
            Ownable1Step.OwnableUnauthorizedAccount.selector,
            address(this)
        ));

        Ownable(hookReceiver).transferOwnership1Step(address(this));
    }
}
