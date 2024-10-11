// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {SiloMathLib} from "silo-core/contracts/lib/SiloMathLib.sol";

contract MulOverflow {
    function mul(uint256 _a, uint256 _b) external pure {
        _a * _b;
    }
}

/*
    forge test -vv --mc MulOverflowTest
*/
contract MulOverflowTest is Test {
    MulOverflow immutable mulOverflow;

    constructor() {
        mulOverflow = new MulOverflow();
    }

    /*
    forge test -vv --mt test_mulOverflow_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_mulOverflow_fuzz(uint256 _a, uint256 _b) public view {
        try mulOverflow.mul(_a, _b) {
            (uint256 mulResult, bool overflow) = SiloMathLib.mulOverflow(_a, _b);
            assertFalse(overflow, "no overflow");
        } catch {
            (uint256 mulResult, bool overflow) = SiloMathLib.mulOverflow(_a, _b);
            assertTrue(overflow, "overflow!");
        }
    }
}
