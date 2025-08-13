// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {KinkMath} from "../../../../contracts/lib/KinkMath.sol";

/*
FOUNDRY_PROFILE=core_test forge test --mc KinkMathLibTest -vv
*/
contract KinkMathLibTest is Test {
    using KinkMath for int256;

    /*
        FOUNDRY_PROFILE=core_test forge test --mt test_kinkMath_isBetween_fuzz -vv
    */
    function test_kinkMath_isBetween_fuzz(int256 _var, int256 _low, int256 _hi) public pure {
        vm.assume(_low <= _hi);

        bool result = _var.isBetween(_low, _hi);

        if (_var < _low || _var > _hi) assertFalse(result, "var is not between");
        else assertTrue(result, "var is between");
    }
}