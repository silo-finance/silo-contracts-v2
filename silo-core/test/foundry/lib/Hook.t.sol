// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {Hook} from "silo-core/contracts/lib/Hook.sol";

/*
forge test -vv --mc HookTest
*/
contract HookTest is Test {
    using Hook for uint256;

    function test_hook_addAction() public pure {
        assertEq(Hook.SAME_ASSET, Hook.NONE.addAction(Hook.SAME_ASSET));
        assertEq(Hook.SAME_ASSET, Hook.SAME_ASSET.addAction(Hook.SAME_ASSET), "nothing was changed");

        uint256 bitmap = Hook.BORROW | Hook.SAME_ASSET;
        assertEq(Hook.BORROW | Hook.SAME_ASSET | Hook.LEVERAGE, bitmap.addAction(Hook.LEVERAGE), "add LEVERAGE");
    }

    function test_hook_removeAction() public pure {
        assertEq(Hook.SAME_ASSET, Hook.SAME_ASSET.removeAction(Hook.NONE), "nothing was removed");

        uint256 bitmap = Hook.BORROW | Hook.SAME_ASSET | Hook.LEVERAGE;
        assertEq(Hook.SAME_ASSET | Hook.LEVERAGE, bitmap.removeAction(Hook.BORROW), "remove WITHDRAW");
    }

    function test_hook_match() public pure {
        uint256 bitmap = Hook.WITHDRAW | Hook.PROTECTED_TOKEN;

        assertTrue(bitmap.matchAction(Hook.WITHDRAW), "match WITHDRAW");
        assertTrue(bitmap.matchAction(Hook.PROTECTED_TOKEN), "match PROTECTED_TOKEN");
        assertTrue(bitmap.matchAction(Hook.WITHDRAW | Hook.PROTECTED_TOKEN), "match all");
    }
}
