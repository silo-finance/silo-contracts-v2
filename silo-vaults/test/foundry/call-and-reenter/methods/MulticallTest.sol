// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {MethodReentrancyTest} from "silo-core/test/foundry/Silo/reentrancy/methods/MethodReentrancyTest.sol";
import {TestStateLib} from "silo-vaults/test/foundry/call-and-reenter/TestState.sol";
import {ISiloVault} from "silo-vaults/contracts/interfaces/ISiloVault.sol";

contract MulticallTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "multicall(bytes[])";
    }

    function _ensureItWillNotRevert() internal {
        ISiloVault vault = TestStateLib.vault();

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(vault.symbol, ());
        calls[1] = abi.encodeCall(vault.name, ());

        vault.multicall(calls);
    }
}
