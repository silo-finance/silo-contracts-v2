// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

contract A {
    function div(uint256 d) external pure {
        1 / d;
    }
}

contract UnassignedCodeTest is Test {
    /*
    FOUNDRY_PROFILE=core_test forge test -vv --mt test_ifUnassignedCodeWillBeExecuted
    */
    function test_ifUnassignedCodeWillBeExecuted() public {
        A a = new A();
        a.div(1);

        vm.expectRevert(); // because of / 0
        a.div(0);
    }
}
