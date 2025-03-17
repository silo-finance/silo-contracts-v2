// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Ownable} from "openzeppelin5/access/Ownable.sol";

import {MethodReentrancyTest} from "silo-core/test/foundry/Silo/reentrancy/methods/MethodReentrancyTest.sol";
import {TestStateLib} from "silo-vaults/test/foundry/call-and-reenter/TestState.sol";
import {ISiloVault} from "silo-vaults/contracts/interfaces/ISiloVault.sol";

contract AcceptGuardianTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "acceptGuardian()";
    }

    function _ensureItWillNotRevert() internal {
        ISiloVault vault = TestStateLib.vault();

        address newGuardian1 = makeAddr("newGuardian1");
        address newGuardian2 = makeAddr("newGuardian2");

        address owner = Ownable(address(vault)).owner();

        vm.prank(owner);
        vault.submitGuardian(newGuardian1);

        vm.prank(owner);
        vault.submitGuardian(newGuardian2);

        vm.warp(block.timestamp + vault.timelock());

        vm.prank(owner);
        vault.acceptGuardian();
    }
}
