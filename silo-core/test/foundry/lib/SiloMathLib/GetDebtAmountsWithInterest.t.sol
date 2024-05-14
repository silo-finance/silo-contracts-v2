// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "silo-core/contracts/lib/SiloMathLib.sol";

// forge test -vv --mc GetDebtAmountsWithInterestTest
contract GetDebtAmountsWithInterestTest is Test {
    /*
    forge test -vv --mt test_getDebtAmountsWithInterest
    */
    function test_getDebtAmountsWithInterest() public {
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
}
