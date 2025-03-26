// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Ownable} from "openzeppelin5/access/Ownable.sol";
import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {MethodReentrancyTest} from "silo-core/test/foundry/Silo/reentrancy/methods/MethodReentrancyTest.sol";
import {TestStateLib} from "silo-vaults/test/foundry/call-and-reenter/TestState.sol";
import {ISiloVault} from "silo-vaults/contracts/interfaces/ISiloVault.sol";
import {ErrorsLib} from "silo-vaults/contracts/libraries/ErrorsLib.sol";

contract AcceptCapTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");

        ISiloVault vault = TestStateLib.vault();

        address market = TestStateLib.market();
        address owner = Ownable(address(vault)).owner();

        vm.prank(owner);
        vault.submitCap(IERC4626(market), 132123e18);

        vm.warp(block.timestamp + vault.timelock());

        vm.prank(owner);
        vault.acceptCap(IERC4626(market));
    }

    function verifyReentrancy() external {
        ISiloVault vault = TestStateLib.vault();

        address market = TestStateLib.market();
        address owner = Ownable(address(vault)).owner();

        vm.prank(owner);
        vault.submitCap(IERC4626(market), 132123e18);

        vm.warp(block.timestamp + vault.timelock());

        vm.expectRevert(ErrorsLib.ReentrancyError.selector);
        vault.acceptCap(IERC4626(market));
    }

    function methodDescription() external pure returns (string memory description) {
        description = "acceptCap(address)";
    }
}
