// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20Errors} from "openzeppelin5/interfaces/draft-IERC6093.sol";

import {MethodReentrancyTest} from "silo-core/test/foundry/Silo/reentrancy/methods/MethodReentrancyTest.sol";
import {TestStateLib} from "silo-vaults/test/foundry/call-and-reenter/TestState.sol";
import {ISiloVault} from "silo-vaults/contracts/interfaces/ISiloVault.sol";
import {ErrorsLib} from "silo-vaults/contracts/libraries/ErrorsLib.sol";

contract SkimTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will revert as expected");
        _ensureRevertWhenSkimRecipientIsZeroAddress();
    }

    function verifyReentrancy() external {
        _ensureRevertWhenSkimRecipientIsZeroAddress();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "skim(address)";
    }

    function _ensureRevertWhenSkimRecipientIsZeroAddress() internal {
        ISiloVault vault = TestStateLib.vault();

        address someToken = makeAddr("someToken");

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        vault.skim(someToken);
    }
}
