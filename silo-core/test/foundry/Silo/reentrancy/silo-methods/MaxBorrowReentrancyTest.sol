// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IMethodReentrancyTest} from "../interfaces/IMethodReentrancyTest.sol";
import {TestStateLib} from "../TestState.sol";

contract MaxBorrowReentrancyTest is Test, IMethodReentrancyTest {
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

    function methodSignature() external pure returns (bytes4 sig) {
        sig = ISilo.maxBorrow.selector;
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
