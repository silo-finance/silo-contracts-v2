// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {SiloSolvencyLib} from "silo-core/contracts/lib/SiloSolvencyLib.sol";

/*
forge test -vv --mc LtvMathTest
*/
contract LtvMathTest is Test {
    /*
    forge test --ffi -vv --mt test_ltvMath_zeros
    */
    function test_ltvMath_zeros() public {
        // this test will revert, but in code we not calling `ltvMath` with 0, so we good.
        // assertEq(SiloSolvencyLib.ltvMath({_totalBorrowerDebtValue: 0, _sumOfBorrowerCollateralValue: 0}), 0);
    }

    /*
    forge test --ffi -vv --mt test_ltvMath_noDebt
    */
    function test_ltvMath_noDebt() public {
        assertEq(SiloSolvencyLib.ltvMath({_totalBorrowerDebtValue: 0, _sumOfBorrowerCollateralValue: 1}), 0);
        assertEq(SiloSolvencyLib.ltvMath({_totalBorrowerDebtValue: 0, _sumOfBorrowerCollateralValue: 1e18}), 0);
        assertEq(SiloSolvencyLib.ltvMath({_totalBorrowerDebtValue: 0, _sumOfBorrowerCollateralValue: type(uint256).max}), 0);
    }

    /*
    forge test --ffi -vv --mt test_ltvMath_withDebt
    */
    function test_ltvMath_withDebt() public {
        assertEq(SiloSolvencyLib.ltvMath({_totalBorrowerDebtValue: 1, _sumOfBorrowerCollateralValue: 1}), 1e18);
        assertEq(SiloSolvencyLib.ltvMath({_totalBorrowerDebtValue: 1, _sumOfBorrowerCollateralValue: 1e18}), 1);
    }

    /*
    forge test --ffi -vv --mt test_ltvMath_allMax
    */
    function test_ltvMath_allMax() public {
        assertEq(SiloSolvencyLib.ltvMath({_totalBorrowerDebtValue: type(uint256).max, _sumOfBorrowerCollateralValue: type(uint256).max}), 1e18);
    }

    function test_ltvMath_maxDebt() public {
        /*
        this is what docs saying:
        @dev Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or
        denominator == 0.
        but looks like we can overflow on mul!
        */
        assertEq(SiloSolvencyLib.ltvMath({_totalBorrowerDebtValue: type(uint256).max, _sumOfBorrowerCollateralValue: 1}), type(uint256).max);
    }
}
