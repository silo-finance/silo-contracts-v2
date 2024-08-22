// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract SynchronizeHooksTokenReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");
        _ensureItWillRevertWithOnlySilo();
    }

    function verifyReentrancy() external {
        _ensureItWillRevertWithOnlySilo();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "synchronizeHooks(uint24,uint24)";
    }

    function _ensureItWillRevertWithOnlySilo() internal {
        vm.expectRevert(IShareToken.OnlySilo.selector);
        IShareToken(address(TestStateLib.silo0())).synchronizeHooks(1, 2);

        vm.expectRevert(IShareToken.OnlySilo.selector);
        IShareToken(address(TestStateLib.silo1())).synchronizeHooks(1, 2);
    }
}
