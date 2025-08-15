// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {RandomLib} from "../../_common/RandomLib.sol";

/*
FOUNDRY_PROFILE=core_test forge test --mc RandomLibTest -vv
*/
contract RandomLibTest is Test {
    using RandomLib for uint256;

    function setUp() public {
        vm.startPrank(address(0x1));
    }

    function test_randomInside(uint256 _n, uint256 _min, uint256 _max) public pure {
        vm.assume(_min < type(uint256).max - 1);
        vm.assume(_min + 1 < _max);

        uint256 result = _n.randomInside(_min, _max);
        assertTrue(_min < result && result < _max, "randomInside fail");
    }

    function test_randomBetween(uint256 _n, uint256 _min, uint256 _max) public pure {
        vm.assume(_min <= _max);

        uint256 result = _n.randomBetween(_min, _max);
        assertTrue(_min <= result && result <= _max, "randomBetween fail");
    }

    function test_randomAbove(uint256 _n, uint256 _min, uint256 _max) public pure {
        vm.assume(_min < _max);

        uint256 result = _n.randomAbove(_min, _max);
        assertTrue(_min < result && result <= _max, "randomAbove fail");
    }

    function test_randomBelow(uint256 _n, uint256 _min, uint256 _max) public pure {
        vm.assume(_min < _max);

        uint256 result = _n.randomBelow(_min, _max);
        assertTrue(_min <= result && result < _max, "randomBelow fail");
    }

     // manual tests

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_randomInside_manual -vv
    */
    function test_randomInside_manual() public pure {
        assertEq(uint256(0).randomInside(0, 100), 1, "randomInside fail: 0 < x=0 < 100");
        assertEq(uint256(10).randomInside(0, 100), 10, "randomInside fail: 0 < x=10 < 100");
        assertEq(uint256(150).randomInside(10, 100), 10 + 1 + (150 % 89), "randomInside fail: 10 < x=150 < 100");
        assertEq(uint256(10).randomInside(3, 5), 4, "randomInside fail: 3 < x=10 < 5");
        assertEq(uint256(80).randomInside(77, 80), 78, "randomInside fail: 77 < x=80 < 80");
        
        assertEq(
            uint256(type(uint256).max - 1).randomInside(0, type(uint256).max), 
            type(uint256).max - 1, 
            "randomInside fail: 0 < x=type(uint256).max - 1 < type(uint256).max"
        );

        assertEq(
            uint256(type(uint256).max).randomInside(0, type(uint256).max), 
            2, 
            "randomInside fail: 0 < x=type(uint256).max < type(uint256).max"
        );
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_randomBetween_manual -vv
    */
    function test_randomBetween_manual() public pure {
        assertEq(uint256(0).randomBetween(0, 100), 0, "randomBetween fail: 0 <= x(0) <= 100");
        assertEq(uint256(10).randomBetween(0, 100), 10, "randomBetween fail: 0 <= x(10) <= 100");
        assertEq(uint256(150).randomBetween(10, 100), 10 + (150 % 91), "randomBetween fail: 10 <= x(150) <= 100");
        assertEq(uint256(10).randomBetween(3, 5), 4, "randomBetween fail: 3 <= x(10) <= 5");
        assertEq(uint256(76).randomBetween(77, 80), 77, "randomBetween fail: 77 <= x(76) <= 80");
        assertEq(uint256(80).randomBetween(77, 80), 80, "randomBetween fail: 77 <= x(80) <= 80");
        assertEq(uint256(81).randomBetween(77, 80), 78, "randomBetween fail: 77 <= x(81) <= 80");
        
        assertEq(
            uint256(type(uint256).max - 1).randomBetween(0, type(uint256).max), 
            type(uint256).max - 1, 
            "randomBetween fail: 0 <= x(type(uint256).max - 1) <= type(uint256).max"
        );

        assertEq(
            uint256(type(uint256).max).randomBetween(0, type(uint256).max), 
            type(uint256).max, 
            "randomBetween fail: 0 <= x(type(uint256).max) <= type(uint256).max"
        );
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_randomAbove_manual -vv
    */
    function test_randomAbove_manual() public pure {
        assertEq(uint256(0).randomAbove(0, 100), 1, "randomAbove fail: 0 < x(0) <= 100");
        assertEq(uint256(10).randomAbove(0, 100), 10, "randomAbove fail: 0 < x(10) <= 100");
        assertEq(uint256(150).randomAbove(10, 100), 10 + 1 + (150 % 90), "randomAbove fail: 10 < x(150) <= 100");
        assertEq(uint256(10).randomAbove(3, 5), 4, "randomAbove fail: 3 < x(10) <= 5");
        assertEq(uint256(76).randomAbove(77, 80), 79, "randomAbove fail: 77 < x(76) <= 80");
        assertEq(uint256(80).randomAbove(77, 80), 80, "randomAbove fail: 77 < x(80) <= 80");
        assertEq(uint256(81).randomAbove(77, 80), 78, "randomAbove fail: 77 < x(81) <= 80");
        
        assertEq(
            uint256(type(uint256).max - 1).randomAbove(0, type(uint256).max), 
            type(uint256).max - 1, 
            "randomAbove fail: 0 < x(type(uint256).max - 1) <= type(uint256).max"
        );

        assertEq(
            uint256(type(uint256).max).randomAbove(0, type(uint256).max), 
            type(uint256).max, 
            "randomAbove fail: 0 < x(type(uint256).max) <= type(uint256).max"
        );
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_randomBelow_manual -vv
    */
    function test_randomBelow_manual() public pure {
        assertEq(uint256(0).randomBelow(0, 100), 0, "randomBelow fail: 0 <= x(0) < 100");
        assertEq(uint256(10).randomBelow(0, 100), 10, "randomBelow fail: 0 <= x(10) < 100");
        assertEq(uint256(150).randomBelow(10, 100), 10 + (150 % 90), "randomBelow fail: 10 <= x(150) < 100");
        assertEq(uint256(10).randomBelow(3, 5), 3, "randomBelow fail: 3 <= x(10) < 5");
        assertEq(uint256(76).randomBelow(77, 80), 78, "randomBelow fail: 77 <= x(76) < 80");
        assertEq(uint256(80).randomBelow(77, 80), 79, "randomBelow fail: 77 <= x(80) < 80");
        assertEq(uint256(81).randomBelow(77, 80), 77, "randomBelow fail: 77 <= x(81) < 80");
        
        assertEq(
            uint256(type(uint256).max - 1).randomBelow(0, type(uint256).max), 
            type(uint256).max - 1, 
            "randomBelow fail: 0 <= x(type(uint256).max - 1) < type(uint256).max"
        );

        assertEq(
            uint256(type(uint256).max).randomBelow(0, type(uint256).max), 
            0, 
            "randomBelow fail: 0 <= x(type(uint256).max) < type(uint256).max"
        );
    }
}
