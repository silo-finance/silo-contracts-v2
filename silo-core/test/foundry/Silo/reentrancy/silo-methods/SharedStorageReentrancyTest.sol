// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IMethodReentrancyTest} from "../interfaces/IMethodReentrancyTest.sol";
import {TestStateLib} from "../TestState.sol";

contract SharedStorageReentrancyTest is Test, IMethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external view {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "sharedStorage()";
    }

    function methodSignature() external pure returns (bytes4 sig) {
        sig = ISilo.sharedStorage.selector;
    }

    function _ensureItWillNotRevert() internal view {
        TestStateLib.silo0().sharedStorage();
        TestStateLib.silo1().sharedStorage();
    }
}
