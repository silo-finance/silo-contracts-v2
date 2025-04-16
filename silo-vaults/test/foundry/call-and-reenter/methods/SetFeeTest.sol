// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {Ownable} from "openzeppelin5/access/Ownable.sol";

import {MethodReentrancyTest} from "silo-core/test/foundry/Silo/reentrancy/methods/MethodReentrancyTest.sol";
import {TestStateLib} from "silo-vaults/test/foundry/call-and-reenter/TestState.sol";
import {ISiloVault} from "silo-vaults/contracts/interfaces/ISiloVault.sol";

contract SetFeeTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it is protected");
        _ensureItIsProtected();
    }

    function verifyReentrancy() external {
        _ensureItIsProtected();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "setFee(uint256)";
    }

    function _ensureItIsProtected() internal {
        ISiloVault vault = TestStateLib.vault();

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        vault.setFee(100e18);
    }
}
