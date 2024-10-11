// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

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
    forge test -vv --mt test_mulOverflow
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_mulOverflow(uint256 _a, uint64 _b) public view {
        vm.assume(_b < 1e18);

        try mulOverflow.mul(_a, _b) {
            vm.assume(false);
        } catch {
            unchecked {
                assertLt(_a * _b, _a, "_a * _b < _a");
            }
        }
    }
}
