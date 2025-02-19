// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Ownable} from "openzeppelin5/access/Ownable.sol";

import {MethodReentrancyTest} from "silo-core/test/foundry/Silo/reentrancy/methods/MethodReentrancyTest.sol";
import {TestStateLib} from "silo-vaults/test/foundry/call-and-reenter/TestState.sol";
import {ISiloVault} from "silo-vaults/contracts/interfaces/ISiloVault.sol";

contract AcceptTimelockTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "acceptTimelock()";
    }

    function _ensureItWillNotRevert() internal {
        ISiloVault vault = TestStateLib.vault();

        uint256 newTimelock = 1 days + 10 seconds;
        address owner = Ownable(address(vault)).owner();

        vm.prank(owner);
        vault.submitTimelock(newTimelock);

        vm.prank(owner);
        vault.submitTimelock(newTimelock - 1 seconds);

        vm.warp(block.timestamp + vault.timelock());

        vm.prank(owner);
        vault.acceptTimelock();
    }
}
