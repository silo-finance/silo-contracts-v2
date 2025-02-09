// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {Hook} from "silo-core/contracts/lib/Hook.sol";

/*
forge test -vv --mc HookTest
*/
contract HookTest is Test {
    using Hook for uint256;

    function test_hook_addAction() public pure {
        assertEq(Hook.BORROW_SAME_ASSET, Hook.NONE.addAction(Hook.BORROW_SAME_ASSET));

        assertEq(
            Hook.BORROW_SAME_ASSET,
            Hook.BORROW_SAME_ASSET.addAction(Hook.BORROW_SAME_ASSET),
            "nothing was changed"
        );

        uint256 bitmap = Hook.TRANSITION_COLLATERAL;

        assertEq(
            Hook.TRANSITION_COLLATERAL | Hook.COLLATERAL_TOKEN,
            bitmap.addAction(Hook.COLLATERAL_TOKEN),
            "add COLLATERAL_TOKEN"
        );
    }

    function test_hook_removeAction() public pure {
        assertEq(Hook.TRANSITION_COLLATERAL, Hook.TRANSITION_COLLATERAL.removeAction(Hook.NONE), "nothing was removed");

        uint256 bitmap = Hook.BORROW | Hook.WITHDRAW;
        assertEq(Hook.BORROW, bitmap.removeAction(Hook.WITHDRAW), "remove WITHDRAW");
    }

    function test_hook_match() public pure {
        uint256 bitmap = Hook.WITHDRAW | Hook.PROTECTED_TOKEN;

        assertTrue(bitmap.matchAction(Hook.WITHDRAW), "match WITHDRAW");
        assertTrue(bitmap.matchAction(Hook.PROTECTED_TOKEN), "match PROTECTED_TOKEN");
        assertTrue(bitmap.matchAction(Hook.WITHDRAW | Hook.PROTECTED_TOKEN), "match all");
    }

    function test_toBoolean_valid() public pure {
        assertFalse(Hook._toBoolean(0), "0 == false");
        assertTrue(Hook._toBoolean(1), "1 == true");
    }

    function test_toBoolean_invalid(uint8 _invalid) public {
        vm.assume(_invalid > 1);

        vm.expectRevert();
        Hook._toBoolean(_invalid);
    }
}
