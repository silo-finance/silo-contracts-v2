// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {Initializable} from "openzeppelin5/proxy/utils/Initializable.sol";

import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract InitializeTokenReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will revert for token initialisation method");
        _ensureItWillRevertWithInvalidInitialization();
    }

    function verifyReentrancy() external {
        _ensureItWillRevertWithInvalidInitialization();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "initialize(address,address,uint24)";
    }

    function _ensureItWillRevertWithInvalidInitialization() internal {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        IShareToken(address(TestStateLib.silo0())).initialize(TestStateLib.silo0(), address(2), 3);

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        IShareToken(address(TestStateLib.silo1())).initialize(TestStateLib.silo1(), address(2), 3);
    }
}
