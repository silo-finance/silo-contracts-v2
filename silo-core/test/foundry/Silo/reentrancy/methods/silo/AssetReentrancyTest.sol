// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {Silo} from "silo-core/contracts/Silo.sol";
import {IMethodReentrancyTest} from "../../interfaces/IMethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract AssetReentrancyTest is Test, IMethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external view {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "asset()";
    }

    function methodSignature() external pure returns (bytes4 sig) {
        sig = Silo.asset.selector;
    }

    function _ensureItWillNotRevert() internal view {
        Silo silo0 = Silo(payable(address(TestStateLib.silo0())));
        Silo silo1 = Silo(payable(address(TestStateLib.silo1())));

        silo0.asset();
        silo1.asset();
    }
}
