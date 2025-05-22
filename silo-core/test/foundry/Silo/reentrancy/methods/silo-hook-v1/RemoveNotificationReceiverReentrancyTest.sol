// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Ownable} from "openzeppelin5/access/Ownable2Step.sol";

import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IIncentiveHook} from "silo-core/contracts/interfaces/IIncentiveHook.sol";
import {INotificationReceiver} from "silo-vaults/contracts/interfaces/INotificationReceiver.sol";

import {TestStateLib} from "../../TestState.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";

contract RemoveNotificationReceiverReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will revert (permissions)");
        _ensureItWillRevert();
    }

    function verifyReentrancy() external {
        _ensureItWillRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "removeNotificationReceiver(address,address,bool)";
    }

    function _ensureItWillRevert() internal {
        address hookReceiver = TestStateLib.hookReceiver();

        vm.expectRevert(abi.encodeWithSelector(
            Ownable.OwnableUnauthorizedAccount.selector,
            address(this)
        ));

        IIncentiveHook(hookReceiver).removeNotificationReceiver(
            IShareToken(address(this)),
            INotificationReceiver(address(this)),
            true
        );
    }
}
