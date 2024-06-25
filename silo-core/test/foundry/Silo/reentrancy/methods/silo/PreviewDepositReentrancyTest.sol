// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {IMethodReentrancyTest} from "../../interfaces/IMethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract PreviewDepositReentrancyTest is Test, IMethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external view {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "previewDeposit(uint256)";
    }

    function methodSignature() external pure returns (bytes4 sig) {
        sig = 0xef8b30f7;
    }

    function _ensureItWillNotRevert() internal view {
        TestStateLib.silo0().previewDeposit(1000_000e18);
        TestStateLib.silo1().previewDeposit(1000_000e18);
    }
}
