// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {ERC20Mock} from "openzeppelin5/mocks/token/ERC20Mock.sol";
import {Stream} from "../../../contracts/modules/Stream.sol";

contract StreamTest is Test {
    ERC20Mock token;
    Stream stream;
    address beneficiary = makeAddr("beneficiary");

    function setUp() public {
        token = new ERC20Mock();
        stream = new Stream(address(this), beneficiary, address(token));
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_constructor

    */
    function test_constructor() public view {

    }
}
