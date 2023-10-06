// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../contracts/GoodJob.sol";

contract GoodJobTest is Test {
    GoodJob public goodJob;

    function test_owner() public {
        goodJob = new GoodJob();
        goodJob.owner();
    }
}
