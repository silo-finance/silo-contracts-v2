// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {MethodReentrancyTest} from "silo-core/test/foundry/Silo/reentrancy/methods/MethodReentrancyTest.sol";
import {TestStateLib} from "silo-vaults/test/foundry/call-and-reenter/TestState.sol";
import {ISiloVault} from "silo-vaults/contracts/interfaces/ISiloVault.sol";

contract AllowanceTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external view {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "allowance(address,address)";
    }

    function _ensureItWillNotRevert() internal view {
        ISiloVault vault = TestStateLib.vault();

        vault.allowance(address(0), address(0));
    }
}
