// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Math, SiloMathLib, Rounding} from "silo-core/contracts/lib/SiloMathLib.sol";

// forge test -vv --mc GetDebtAmountsWithInterestTest
contract GetDebtAmountsWithInterestTest is Test {
    using Math for uint256;

    uint256 internal constant _PRECISION_DECIMALS = 1e18;

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
    forge test -vv --mt test_getDebtAmountsWithInterest_notRevert
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_getDebtAmountsWithInterest_notRevert_fuzz(uint256 _debtAssets, uint256 _rcompInDp) public pure {
        SiloMathLib.getDebtAmountsWithInterest(_debtAssets, _rcompInDp);
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

    /*
    forge test -vv --mt test_getDebtAmountsWithInterest_cap
    */
    function test_getDebtAmountsWithInterest_cap() public pure {
        uint256 debtAssets = 1e18;
        // this should be impossible because of IRM cap, but for QA we have to support it
        uint256 rcompInDp = type(uint256).max - 1;

        uint256 interest = debtAssets.mulDiv(rcompInDp, _PRECISION_DECIMALS, Rounding.ACCRUED_INTEREST);
        assertLt(interest, type(uint256).max, "this is just to ensure, we testing cap, not overflow on interest");

        (
            uint256 debtAssetsWithInterest, uint256 accruedInterest
        ) = SiloMathLib.getDebtAmountsWithInterest(debtAssets, rcompInDp);

        assertEq(debtAssetsWithInterest, type(uint256).max, "debtAssetsWithInterest - max");
        assertEq(accruedInterest, type(uint256).max - 1e18, "accruedInterest");
        assertLt(accruedInterest, interest, "accruedInterest cap");
    }
}
