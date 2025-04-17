// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

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
        vm.expectRevert();
        SiloSolvencyLib.ltvMath({_totalBorrowerDebtValue: 0, _sumOfBorrowerCollateralValue: 0});
    }

    /*
    forge test --ffi -vv --mt test_ltvMath_noDebt
    */
    function test_ltvMath_noDebt() public pure {
        assertEq(SiloSolvencyLib.ltvMath({_totalBorrowerDebtValue: 0, _sumOfBorrowerCollateralValue: 1}), 0);
        assertEq(SiloSolvencyLib.ltvMath({_totalBorrowerDebtValue: 0, _sumOfBorrowerCollateralValue: 1e18}), 0);
        assertEq(SiloSolvencyLib.ltvMath({
            _totalBorrowerDebtValue: 0, _sumOfBorrowerCollateralValue: type(uint256).max
        }), 0);
    }

    /*
    forge test --ffi -vv --mt test_ltvMath_withDebt
    */
    function test_ltvMath_withDebt() public pure {
        assertEq(SiloSolvencyLib.ltvMath({_totalBorrowerDebtValue: 1, _sumOfBorrowerCollateralValue: 1}), 1e18);
        assertEq(SiloSolvencyLib.ltvMath({_totalBorrowerDebtValue: 1, _sumOfBorrowerCollateralValue: 1e18}), 1);
    }

    /*
    forge test --ffi -vv --mt test_ltvMath_allMax
    */
    function test_ltvMath_allMax() public pure {
        assertEq(SiloSolvencyLib.ltvMath({
            _totalBorrowerDebtValue: type(uint256).max, _sumOfBorrowerCollateralValue: type(uint256).max
        }), 1e18);
    }

    function test_ltvMath_maxDebt() public pure {
        assertEq(SiloSolvencyLib.ltvMath({
            _totalBorrowerDebtValue: type(uint256).max, _sumOfBorrowerCollateralValue: 1e18
        }), type(uint256).max);
    }

    function test_ltvMath_overflow() public {
        vm.expectRevert();
        SiloSolvencyLib.ltvMath({_totalBorrowerDebtValue: type(uint256).max, _sumOfBorrowerCollateralValue: 1e18 - 1});
    }

    function test_ltvMath_rounding() public pure {
        assertEq(SiloSolvencyLib.ltvMath({
            _totalBorrowerDebtValue: 1, _sumOfBorrowerCollateralValue: 3
        }), 333333333333333334, "0.3(3) ceil +1");
    }
}
