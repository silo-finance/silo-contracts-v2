// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {MethodReentrancyTest} from "silo-core/test/foundry/Silo/reentrancy/methods/MethodReentrancyTest.sol";
import {TestStateLib} from "silo-vaults/test/foundry/call-and-reenter/TestState.sol";
import {ISiloVault} from "silo-vaults/contracts/interfaces/ISiloVault.sol";
import {ErrorsLib} from "silo-vaults/contracts/libraries/ErrorsLib.sol";

contract ClaimRewardsTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");
        
        ISiloVault vault = TestStateLib.vault();
        vault.claimRewards();
    }

    function verifyReentrancy() external {
        ISiloVault vault = TestStateLib.vault();

        vm.expectRevert(ErrorsLib.ReentrancyError.selector);
        vault.claimRewards();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "claimRewards()";
    }
}
