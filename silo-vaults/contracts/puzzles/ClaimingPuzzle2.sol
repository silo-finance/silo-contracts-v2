// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

contract ClaimingPuzzle2 {
    address constant target = address(1);

    function claim() external {
        // some claiming logic
        target.soSomething();
    }
}
