// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC4626} from "openzeppelin5/token/ERC20/extensions/ERC4626.sol";

import {MethodReentrancyTest} from "silo-core/test/foundry/Silo/reentrancy/methods/MethodReentrancyTest.sol";
import {TestStateLib} from "silo-vaults/test/foundry/call-and-reenter/TestState.sol";
import {ISiloVault} from "silo-vaults/contracts/interfaces/ISiloVault.sol";

contract ArbitraryLossThresholdTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external view {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "arbitraryLossThreshold(address)";
    }

    function _ensureItWillNotRevert() internal view {
        ISiloVault vault = TestStateLib.vault();

        vault.arbitraryLossThreshold(ERC4626(address(0)));
    }
}
