// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {MethodReentrancyTest} from "silo-core/test/foundry/Silo/reentrancy/methods/MethodReentrancyTest.sol";
import {TestStateLib} from "silo-vaults/test/foundry/call-and-reenter/TestState.sol";
import {ISiloVault} from "silo-vaults/contracts/interfaces/ISiloVault.sol";

contract ReentrancyGuardEnteredTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");
        ISiloVault vault = TestStateLib.vault();
        bool isEntered = vault.reentrancyGuardEntered();
        assertFalse(isEntered, "reentrancyGuardEntered");
    }

    function verifyReentrancy() external view {
        ISiloVault vault = TestStateLib.vault();

        bool isEntered = vault.reentrancyGuardEntered();
        assertTrue(isEntered, "reentrancyGuardEntered");
    }

    function methodDescription() external pure returns (string memory description) {
        description = "reentrancyGuardEntered()";
    }
}
