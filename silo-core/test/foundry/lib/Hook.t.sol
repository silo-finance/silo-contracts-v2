// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {Hook} from "silo-core/contracts/lib/Hook.sol";

/*
forge test -vv --mc HookTest
*/
contract HookTest is Test {
    using Hook for uint256;

    function test_hook_addAction() public {
        assertEq(Hook.SAME_ASSET, Hook.NONE.addAction(Hook.SAME_ASSET));
        assertEq(Hook.SAME_ASSET, Hook.SAME_ASSET.addAction(Hook.SAME_ASSET), "nothing was changed");

        uint256 bitmap = Hook.AFTER | Hook.WITHDRAW;
        assertEq(Hook.AFTER | Hook.WITHDRAW | Hook.LEVERAGE, bitmap.addAction(Hook.LEVERAGE), "add LEVERAGE");
    }

    function test_hook_removeAction() public {
        assertEq(Hook.SAME_ASSET, Hook.SAME_ASSET.removeAction(Hook.NONE), "nothing was removed");

        uint256 bitmap = Hook.AFTER | Hook.WITHDRAW | Hook.LEVERAGE;
        assertEq(Hook.AFTER | Hook.LEVERAGE, bitmap.removeAction(Hook.WITHDRAW), "remove WITHDRAW");
    }
}
