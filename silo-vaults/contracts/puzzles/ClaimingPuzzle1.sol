// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

contract ClaimingPuzzle1 {
    address constant target = address(1);

    function claim() external {
        target.claimRewardsOnSomePlace();
    }
}
