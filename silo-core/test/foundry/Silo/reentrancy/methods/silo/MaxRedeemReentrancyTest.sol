// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {IMethodReentrancyTest} from "../../interfaces/IMethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract MaxRedeemReentrancyTest is Test, IMethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "maxRedeem(address)";
    }

    function methodSignature() external pure returns (bytes4 sig) {
        sig = 0xd905777e;
    }

    function _ensureItWillNotRevert() internal {
        address anyAddr = makeAddr("Any address");

        TestStateLib.silo0().maxRedeem(anyAddr);
        TestStateLib.silo1().maxRedeem(anyAddr);
    }
}
