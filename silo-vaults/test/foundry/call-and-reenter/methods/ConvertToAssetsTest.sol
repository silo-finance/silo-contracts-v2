// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {MethodReentrancyTest} from "silo-core/test/foundry/Silo/reentrancy/methods/MethodReentrancyTest.sol";
import {TestStateLib} from "silo-vaults/test/foundry/call-and-reenter/TestState.sol";
import {ISiloVault} from "silo-vaults/contracts/interfaces/ISiloVault.sol";

contract ConvertToAssetsTest is MethodReentrancyTest {
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

    function _ensureItWillNotRevert() internal view {
        ISiloVault vault = TestStateLib.vault();

        vault.convertToAssets(0);
    }
}
