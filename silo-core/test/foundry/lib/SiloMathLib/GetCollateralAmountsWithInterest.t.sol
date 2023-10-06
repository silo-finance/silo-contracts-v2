// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "silo-core/contracts/lib/SiloMathLib.sol";

// forge test -vv --mc GetCollateralAmountsWithInterestTest
contract GetCollateralAmountsWithInterestTest is Test {
    /*
    forge test -vv --mt test_getCollateralAmountsWithInterest
    */
    function test_getCollateralAmountsWithInterest() public {
        uint256 collateralAssets;
        uint256 debtAssets;
        uint256 rcompInDp;
        uint256 daoFeeInBp;
        uint256 deployerFeeInBp;

        (
            uint256 collateralAssetsWithInterest,
            uint256 debtAssetsWithInterest,
            uint256 daoAndDeployerFees,
            uint256 accruedInterest
        ) = SiloMathLib.getCollateralAmountsWithInterest(collateralAssets, debtAssets, rcompInDp, daoFeeInBp, deployerFeeInBp);

        assertEq(collateralAssetsWithInterest, 0);
        assertEq(debtAssetsWithInterest, 0);
        assertEq(daoAndDeployerFees, 0);
        assertEq(accruedInterest, 0);

        collateralAssets = 2e18;
        debtAssets = 1e18;
        rcompInDp = 0.1e18;

        (
            collateralAssetsWithInterest,
            debtAssetsWithInterest,
            daoAndDeployerFees,
            accruedInterest
        ) = SiloMathLib.getCollateralAmountsWithInterest(collateralAssets, debtAssets, rcompInDp, daoFeeInBp, deployerFeeInBp);

        assertEq(collateralAssetsWithInterest, 2.1e18, "collateralAssetsWithInterest, just rcomp");
        assertEq(debtAssetsWithInterest, 1.1e18, "debtAssetsWithInterest, just rcomp");
        assertEq(daoAndDeployerFees, 0, "daoAndDeployerFees, just rcomp");
        assertEq(accruedInterest, 0.1e18, "accruedInterest, just rcomp");

        daoFeeInBp = 0.05e4;

        (
            collateralAssetsWithInterest,
            debtAssetsWithInterest,
            daoAndDeployerFees,
            accruedInterest
        ) = SiloMathLib.getCollateralAmountsWithInterest(collateralAssets, debtAssets, rcompInDp, daoFeeInBp, deployerFeeInBp);

        assertEq(collateralAssetsWithInterest, 2.095e18, "collateralAssetsWithInterest, rcomp + daoFee");
        assertEq(debtAssetsWithInterest, 1.1e18, "debtAssetsWithInterest, rcomp + daoFee");
        assertEq(daoAndDeployerFees, 0.005e18, "daoAndDeployerFees, rcomp + daoFee");
        assertEq(accruedInterest, 0.1e18, "accruedInterest, rcomp + daoFee");

        deployerFeeInBp = 0.05e4;
        daoFeeInBp = 0;

        (
            collateralAssetsWithInterest,
            debtAssetsWithInterest,
            daoAndDeployerFees,
            accruedInterest
        ) = SiloMathLib.getCollateralAmountsWithInterest(collateralAssets, debtAssets, rcompInDp, daoFeeInBp, deployerFeeInBp);

        assertEq(collateralAssetsWithInterest, 2.095e18, "collateralAssetsWithInterest, rcomp + deployerFeeInBp");
        assertEq(debtAssetsWithInterest, 1.1e18, "debtAssetsWithInterest, rcomp + deployerFeeInBp");
        assertEq(daoAndDeployerFees, 0.005e18, "daoAndDeployerFees, rcomp + deployerFeeInBp");
        assertEq(accruedInterest, 0.1e18, "accruedInterest, rcomp + deployerFeeInBp");

        deployerFeeInBp = 0.05e4;
        daoFeeInBp = 0.05e4;

        (
            collateralAssetsWithInterest,
            debtAssetsWithInterest,
            daoAndDeployerFees,
            accruedInterest
        ) = SiloMathLib.getCollateralAmountsWithInterest(collateralAssets, debtAssets, rcompInDp, daoFeeInBp, deployerFeeInBp);

        assertEq(collateralAssetsWithInterest, 2.090e18, "collateralAssetsWithInterest, rcomp + fees");
        assertEq(debtAssetsWithInterest, 1.1e18, "debtAssetsWithInterest, rcomp + fees");
        assertEq(daoAndDeployerFees, 0.01e18, "daoAndDeployerFees, rcomp + fees");
        assertEq(accruedInterest, 0.1e18, "accruedInterest, rcomp + fees");

        debtAssets = 0;

        (
            collateralAssetsWithInterest,
            debtAssetsWithInterest,
            daoAndDeployerFees,
            accruedInterest
        ) = SiloMathLib.getCollateralAmountsWithInterest(collateralAssets, debtAssets, rcompInDp, daoFeeInBp, deployerFeeInBp);

        assertEq(collateralAssetsWithInterest, 2e18, "collateralAssetsWithInterest - no debt, no interest");
        assertEq(debtAssetsWithInterest, 0, "debtAssetsWithInterest - no debt, no interest");
        assertEq(daoAndDeployerFees, 0, "daoAndDeployerFees - no debt, no interest");
        assertEq(accruedInterest, 0, "accruedInterest - no debt, no interest");
    }
}
