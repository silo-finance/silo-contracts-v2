// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {CrossReentrancyGuard} from "silo-core/contracts/utils/CrossReentrancyGuard.sol";

contract CrossReentrancyGuardImpl is CrossReentrancyGuard {
    function onlySiloOrTokenOrHookReceiver() external virtual {
        _onlySiloOrTokenOrHookReceiver();
    }
}

/*
FOUNDRY_PROFILE=core_test forge test -vv --mc CrossReentrancyGuardTest
*/
contract CrossReentrancyGuardTest is Test {
    // this test purpose is make coverage for `_onlySiloOrTokenOrHookReceiver` method
    function test_onlySiloOrTokenOrHookReceiver() public {
        CrossReentrancyGuardImpl impl = new CrossReentrancyGuardImpl();
        impl.onlySiloOrTokenOrHookReceiver();
    }
}
