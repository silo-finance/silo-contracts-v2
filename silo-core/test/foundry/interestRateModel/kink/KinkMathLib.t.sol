// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {KinkMath} from "../../../../contracts/lib/KinkMath.sol";

/*
FOUNDRY_PROFILE=core_test forge test --mc KinkMathLibTest -vv
*/
contract KinkMathLibTest is Test {
    using KinkMath for int256;
    using KinkMath for uint256;

    /*
        FOUNDRY_PROFILE=core_test forge test --mt test_kinkMath_isBetween_fuzz -vv
    */
    function test_kinkMath_isBetween_fuzz(int256 _var, int256 _low, int256 _hi) public pure {
        vm.assume(_low <= _hi);

        bool result = _var.isBetween(_low, _hi);

        if (_low <= _var && _var <= _hi) assertTrue(result, "var should be between");
        else assertFalse(result, "var should NOT be between");
    }

    /*
        FOUNDRY_PROFILE=core_test forge test --mt test_kinkMath_isInBelow_fuzz -vv
    */
    function test_kinkMath_isInBelow_fuzz(int256 _var, int256 _low, int256 _hi) public pure {
        vm.assume(_low <= _hi);

        bool result = _var.isInBelow(_low, _hi);

        if (_low <= _var && _var < _hi) assertTrue(result, "var should be in below");
        else assertFalse(result, "var should NOT be in below");
    }

    /*
        FOUNDRY_PROFILE=core_test forge test --mt test_kinkMath_isInAbove_fuzz -vv
    */
    function test_kinkMath_isInAbove_fuzz(int256 _var, int256 _low, int256 _hi) public pure {
        vm.assume(_low <= _hi);

        bool result = _var.isInAbove(_low, _hi);

        if (_low < _var && _var <= _hi) assertTrue(result, "var should be in above");
        else assertFalse(result, "var should NOT be in above");
    }

    /*
        FOUNDRY_PROFILE=core_test forge test --mt test_kinkMath_isInside_fuzz -vv
    */
    function test_kinkMath_isInside_fuzz(int256 _var, int256 _low, int256 _hi) public pure {
        vm.assume(_low < _hi);

        bool result = _var.isInside(_low, _hi);

        if (_low < _var && _var < _hi) assertTrue(result, "var should be inside");
        else assertFalse(result, "var should NOT be inside");
    }

    /*
        FOUNDRY_PROFILE=core_test forge test --mt test_kinkMath_willOverflowOnCastToInt256_fuzz -vv
    */
    function test_kinkMath_willOverflowOnCastToInt256_fuzz(uint256 _value) public pure {
        bool result = _value.willOverflowOnCastToInt256();

        if (_value > uint256(type(int256).max)) assertTrue(result, "value should overflow");
        else assertFalse(result, "value should NOT overflow");
    }
}