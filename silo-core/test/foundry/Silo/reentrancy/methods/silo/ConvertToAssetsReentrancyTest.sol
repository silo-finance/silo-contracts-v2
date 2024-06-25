// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {Silo} from "silo-core/contracts/Silo.sol";
import {IMethodReentrancyTest} from "../../interfaces/IMethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract ConvertToAssetsReentrancyTest is Test, IMethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external view {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "convertToAssets(uint256)";
    }

    function methodSignature() external pure returns (bytes4 sig) {
        sig = 0x07a2d13a;
    }

    function _ensureItWillNotRevert() internal view {
        Silo(payable(address(TestStateLib.silo0()))).convertToAssets(100e18);
        Silo(payable(address(TestStateLib.silo1()))).convertToAssets(100e18);
    }
}
