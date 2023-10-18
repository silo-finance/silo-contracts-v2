// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "silo-core/contracts/lib/SiloMathLib.sol";

// forge test -vv --mc CalculateMaxValueToWithdrawTest
contract CalculateMaxAssetsToWithdrawTest is Test {
    /*
    forge test -vv --mt test_calculateMaxAssetsToWithdraw
    */
    function test_calculateMaxAssetsToWithdraw() public {
        assertEq(SiloMathLib.calculateMaxAssetsToWithdraw(0, 0, 0, 0, 0), 0, "when all zeros");

        assertEq(SiloMathLib.calculateMaxAssetsToWithdraw(1, 0, 0, 1, 0), 1, "when no debt");
        assertEq(SiloMathLib.calculateMaxAssetsToWithdraw(1, 0, 0, 0, 1), 1, "when no debt");

        assertEq(SiloMathLib.calculateMaxAssetsToWithdraw(100, 1, 0, 0, 0), 0, "when over LT");

        assertEq(
            // sumOfCollateralsValue, debtValue, ltInBp, borrowerCollateralAssets, borrowerProtectedAssets
            SiloMathLib.calculateMaxAssetsToWithdraw(1e4, 1, 1, 0, 0),
            0, "LT is 0.01% and LTV is 0.01%"
        );

        // sumOfCollateralsValue, debtValue, ltInBp, borrowerCollateralAssets, borrowerProtectedAssets
        assertEq(SiloMathLib.calculateMaxAssetsToWithdraw(1e4, 1, 100, 0.5e4, 0.5e4), 9900);
        assertEq(SiloMathLib.calculateMaxAssetsToWithdraw(1e4, 1, 100, 0.8e4, 0.2e4), 9900);
        assertEq(SiloMathLib.calculateMaxAssetsToWithdraw(1e4, 1, 100, 1e4, 0e4), 9900);
        assertEq(SiloMathLib.calculateMaxAssetsToWithdraw(1e4, 1, 100, 0e4, 1e4), 9900);
        assertEq(SiloMathLib.calculateMaxAssetsToWithdraw(1e4, 1, 100, 1e4, 1e4), 9900 * 2);

        assertEq(
            // sumOfCollateralsValue, debtValue, ltInBp, borrowerCollateralAssets, borrowerProtectedAssets
            SiloMathLib.calculateMaxAssetsToWithdraw(100, 80, 8000, 0, 0),
            0, "exact LT"
        );

        // sumOfCollateralsValue, debtValue, ltInBp, borrowerCollateralAssets, borrowerProtectedAssets
        assertEq(SiloMathLib.calculateMaxAssetsToWithdraw(101, 80, 8000, 100, 1), 1);

        // sumOfCollateralsValue, debtValue, ltInBp, borrowerCollateralAssets, borrowerProtectedAssets
        assertEq(SiloMathLib.calculateMaxAssetsToWithdraw(10, 8, 8888, 10, 10), 2, "8/(10 - 1) => 88,88%");

        // sumOfCollateralsValue, debtValue, ltInBp, borrowerCollateralAssets, borrowerProtectedAssets
        assertEq(SiloMathLib.calculateMaxAssetsToWithdraw(10e18, 8e18, 8888, 5e18, 5e18), 999099909990999100, "LTV after => 88,88%");
        assertEq(SiloMathLib.calculateMaxAssetsToWithdraw(10e18, 8e18, 8888, 1e18, 1e18), 999099909990999100 / 5, "LTV after => 88,88%");
    }
}
