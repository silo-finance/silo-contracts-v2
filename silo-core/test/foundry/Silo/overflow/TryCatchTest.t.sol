// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

contract Overflows {
    error SomeError();

    function zeroDiv() public pure returns (uint256) {
        return uint256(1) / uint256(0);
    }

    function underflow() public pure  returns (uint256) {
        return uint256(0) - uint256(1);
    }

    function overflow() public pure  returns (uint256) {
        return type(uint256).max + uint256(1);
    }

    function customError() public pure {
        revert SomeError();
    }

    function standardRevert() public pure {
        revert("oops");
    }
}

/*
    forge test -vv --ffi --mc TryCatchTest
*/
contract TryCatchTest is Test {
    Overflows overflows;

    constructor() {
        overflows = new Overflows();
    }

    function test_catch_divByZero() public view {
        try overflows.zeroDiv() {
            assert(false);
        } catch {
            return;
        }

        // regular catch should work for / 0
        assert(false);
    }

    function test_catch_underflow() public view {
        try overflows.underflow() {
            assert(false);
        } catch {
            return;
        }

        // regular catch should work for underflow
        assert(false);
    }

    function test_catch_overflow() public view {
        try overflows.overflow() {
            assert(false);
        } catch {
            return;
        }

        // regular catch should work for overflow
        assert(false);
    }

    function test_catch_customError() public view {
        try overflows.customError() {
            assert(false);
        } catch {
            return;
        }

        // regular catch should work for customError
        assert(false);
    }

    function test_catch_standardRevert() public view {
        try overflows.standardRevert() {
            assert(false);
        } catch {
            return;
        }

        // regular catch should work for standardRevert
        assert(false);
    }
}
