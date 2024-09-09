// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "silo-core/contracts/lib/SiloMathLib.sol";

// forge test -vv --mc GetDebtAmountsWithInterestTest
contract GetDebtAmountsWithInterestTest is Test {
    /*
    forge test -vv --mt test_getDebtAmountsWithInterest_pass
    */
    function test_getDebtAmountsWithInterest_pass() public pure {
        uint256 debtAssets;
        uint256 rcompInDp;

        (uint256 debtAssetsWithInterest, uint256 accruedInterest) =
            SiloMathLib.getDebtAmountsWithInterest(debtAssets, rcompInDp);

        assertEq(debtAssetsWithInterest, 0);
        assertEq(accruedInterest, 0);

        rcompInDp = 0.1e18;

        (debtAssetsWithInterest, accruedInterest) = SiloMathLib.getDebtAmountsWithInterest(debtAssets, rcompInDp);

        assertEq(debtAssetsWithInterest, 0, "debtAssetsWithInterest, just rcomp");
        assertEq(accruedInterest, 0, "accruedInterest, just rcomp");

        debtAssets = 1e18;

        (debtAssetsWithInterest, accruedInterest) = SiloMathLib.getDebtAmountsWithInterest(debtAssets, rcompInDp);

        assertEq(debtAssetsWithInterest, 1.1e18, "debtAssetsWithInterest - no debt, no interest");
        assertEq(accruedInterest, 0.1e18, "accruedInterest - no debt, no interest");
    }

    /*
    forge test -vv --mt test_getDebtAmountsWithInterest_overflow_max
    */
    function test_getDebtAmountsWithInterest_overflow_max() public pure {
        uint256 debtAssets = type(uint256).max;
        // this should be impossible because of IRM cap, but for QA we have to support it
        uint256 rcompInDp = type(uint256).max;

        (
            uint256 debtAssetsWithInterest, uint256 accruedInterest
        ) = SiloMathLib.getDebtAmountsWithInterest(debtAssets, rcompInDp);

        assertEq(debtAssetsWithInterest, type(uint256).max, "debtAssetsWithInterest - max");
        assertEq(accruedInterest, 0, "accruedInterest - overflow cap");
    }

    /*
    forge test -vv --mt test_getDebtAmountsWithInterest_overflow_interest
    */
    function test_getDebtAmountsWithInterest_overflow_interest() public pure {
        uint256 debtAssets = type(uint256).max - 1e18;
        // this should be impossible because of IRM cap, but for QA we have to support it
        uint256 rcompInDp = 1e18; // 100 %

        (
            uint256 debtAssetsWithInterest, uint256 accruedInterest
        ) = SiloMathLib.getDebtAmountsWithInterest(debtAssets, rcompInDp);

        assertEq(debtAssetsWithInterest, type(uint256).max, "debtAssetsWithInterest - max");
        assertEq(accruedInterest, 1e18, "accruedInterest - overflow cap");
    }

    /*
    forge test -vv --mt test_getDebtAmountsWithInterest_overflow_one
    */
    function test_getDebtAmountsWithInterest_overflow_one() public pure {
        uint256 debtAssets = type(uint256).max / 2 + 1;
        // this should be impossible because of IRM cap, but for QA we have to support it
        uint256 rcompInDp = 1e18; // 100 %

        (
            uint256 debtAssetsWithInterest, uint256 accruedInterest
        ) = SiloMathLib.getDebtAmountsWithInterest(debtAssets, rcompInDp);

        assertEq(debtAssetsWithInterest, type(uint256).max, "debtAssetsWithInterest - max");
        assertEq(accruedInterest, type(uint256).max / 2, "accruedInterest - overflow cap");
    }

    /*
    forge test -vv --mt test_getDebtAmountsWithInterest_below_overflow
    */
    function test_getDebtAmountsWithInterest_below_overflow() public pure {
        uint256 debtAssets = type(uint256).max / 2;
        // this should be impossible because of IRM cap, but for QA we have to support it
        uint256 rcompInDp = 1e18; // 100 %

        (
            uint256 debtAssetsWithInterest, uint256 accruedInterest
        ) = SiloMathLib.getDebtAmountsWithInterest(debtAssets, rcompInDp);

        assertEq(debtAssetsWithInterest, type(uint256).max - 1, "debtAssetsWithInterest - max");
        assertEq(accruedInterest, type(uint256).max / 2, "accruedInterest - overflow cap");
    }
    }
}
