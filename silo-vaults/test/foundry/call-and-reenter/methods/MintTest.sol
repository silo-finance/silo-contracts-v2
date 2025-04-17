// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {MaliciousToken} from "silo-vaults/test/foundry/call-and-reenter/MaliciousToken.sol";
import {MethodReentrancyTest} from "silo-core/test/foundry/Silo/reentrancy/methods/MethodReentrancyTest.sol";
import {TestStateLib} from "silo-vaults/test/foundry/call-and-reenter/TestState.sol";
import {ISiloVault} from "silo-vaults/contracts/interfaces/ISiloVault.sol";
import {ErrorsLib} from "silo-vaults/contracts/libraries/ErrorsLib.sol";

contract MintTest is MethodReentrancyTest {
    function callMethod() external {
        MaliciousToken token = MaliciousToken(TestStateLib.asset());
        ISiloVault vault = TestStateLib.vault();
        address depositor = makeAddr("Depositor");
        uint256 amount = 100e18;

        TestStateLib.disableReentrancy();

        token.mint(depositor, amount);

        vm.prank(depositor);
        token.approve(address(vault), amount);

        TestStateLib.enableReentrancy();

        vm.prank(depositor);
        vault.mint(amount, depositor);
    }

    function verifyReentrancy() external {
        ISiloVault vault = TestStateLib.vault();

        vm.expectRevert(ErrorsLib.ReentrancyError.selector);
        vault.mint(1000, address(0));
    }

    function methodDescription() external pure returns (string memory description) {
        description = "mint(uint256,address)";
    }
}
