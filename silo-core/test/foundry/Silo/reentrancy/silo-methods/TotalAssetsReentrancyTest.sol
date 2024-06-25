// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {Silo} from "silo-core/contracts/Silo.sol";
import {IMethodReentrancyTest} from "../interfaces/IMethodReentrancyTest.sol";
import {TestStateLib} from "../TestState.sol";

contract TotalAssetsReentrancyTest is Test, IMethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external view {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "total()";
    }

    function methodSignature() external pure returns (bytes4 sig) {
        sig = Silo.totalAssets.selector;
    }

    function _ensureItWillNotRevert() internal view {
        Silo(payable(address(TestStateLib.silo0()))).totalAssets();
        Silo(payable(address(TestStateLib.silo1()))).totalAssets();
    }
}
