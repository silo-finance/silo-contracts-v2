// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {IMethodReentrancyTest} from "../../interfaces/IMethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract PreviewMintReentrancyTest is Test, IMethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external view {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "previewMint(uint256)";
    }

    function methodSignature() external pure returns (bytes4 sig) {
        sig = 0xb3d7f6b9;
    }

    function _ensureItWillNotRevert() internal view {
        TestStateLib.silo0().previewMint(1000_000e18);
        TestStateLib.silo1().previewMint(1000_000e18);
    }
}
