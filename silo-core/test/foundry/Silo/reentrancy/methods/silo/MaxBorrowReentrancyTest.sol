// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract MaxBorrowReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "maxBorrow(address,bool)";
    }

    function _ensureItWillNotRevert() internal {
        address anyAddr = makeAddr("Any address");
        bool sameAsset = true;

        TestStateLib.silo0().maxBorrow(anyAddr, sameAsset);
        TestStateLib.silo1().maxBorrow(anyAddr, sameAsset);

        TestStateLib.silo0().maxBorrow(anyAddr, !sameAsset);
        TestStateLib.silo1().maxBorrow(anyAddr, !sameAsset);
    }
}
