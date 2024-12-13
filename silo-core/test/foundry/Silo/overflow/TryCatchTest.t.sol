// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

contract Oveflows {
    error SomeError();

    function zeroDiv() external pure returns (uint256) {
        return uint256(1) / uint256(0);
    }

    function underflow() external pure  returns (uint256) {
        return uint256(0) - uint256(1);
    }

    function overflow() external pure  returns (uint256) {
        return type(uint256).max + uint256(1);
    }

    function customError() external pure {
        revert SomeError();
    }

    function standardRevert() external pure {
        revert("oops");
    }
}

/*
    forge test -vv --ffi --mc TryCatchTest
*/
contract TryCatchTest is Test {
    Oveflows oveflows;

    constructor() {
        oveflows = new Oveflows();
    }

    function test_catch_divByZero() public view {
        try oveflows.zeroDiv() {
            assert(false);
        } catch {
            return;
        }

        // regular catch should work for / 0
        assert(false);
    }

    function test_catch_underflow() public view {
        try oveflows.underflow() {
            assert(false);
        } catch {
            return;
        }

        // regular catch should work for underflow
        assert(false);
    }

    function test_catch_overflow() public view {
        try oveflows.overflow() {
            assert(false);
        } catch {
            return;
        }

        // regular catch should work for overflow
        assert(false);
    }

    function test_catch_customError() public view {
        try oveflows.customError() {
            assert(false);
        } catch {
            return;
        }

        // regular catch should work for customError
        assert(false);
    }

    function test_catch_standardRevert() public view {
        try oveflows.standardRevert() {
            assert(false);
        } catch {
            return;
        }

        // regular catch should work for standardRevert
        assert(false);
    }
}
