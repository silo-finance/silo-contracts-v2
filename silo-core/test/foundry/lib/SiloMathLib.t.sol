// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../../contracts/lib/SiloMathLib.sol";

// forge test -vv --mc SiloMathLibTest
contract SiloMathLibTest is Test {
    address public config = address(10001);
    address public asset = address(10002);
    address public model = address(10003);

    // TODO remove fuzz
    function test_liquidity(uint256 _collateralAssets, uint256 _debtAssets) public {
        if (_debtAssets >= _collateralAssets) {
            assertEq(SiloMathLib.liquidity(_collateralAssets, _debtAssets), 0);
        } else {
            assertEq(SiloMathLib.liquidity(_collateralAssets, _debtAssets), _collateralAssets - _debtAssets);
        }
    }

    // TODO remove fuzz
    function test_calculateUtilization(uint256 _collateralAssets, uint256 _debtAssets) public {
        uint256 dp = 1e18;

        vm.assume(_collateralAssets > 0);
        vm.assume(_debtAssets < type(uint128).max);
        uint256 u = _debtAssets * dp / _collateralAssets;
        vm.assume(u <= dp);

        assertEq(SiloMathLib.calculateUtilization(dp, _collateralAssets, _debtAssets), u);

        assertEq(SiloMathLib.calculateUtilization(dp, 1e18, 0.9e18), 0.9e18);
        assertEq(SiloMathLib.calculateUtilization(dp, 1e18, 0.1e18), 0.1e18);
        assertEq(SiloMathLib.calculateUtilization(dp, 10e18, 1e18), 0.1e18);
        assertEq(SiloMathLib.calculateUtilization(dp, 100e18, 25e18), 0.25e18);
        assertEq(SiloMathLib.calculateUtilization(dp, 100e18, 49e18), 0.49e18);
    }

    // TODO remove fuzz
    function test_calculateUtilizationWithMax(uint256 _dp, uint256 _collateralAssets, uint256 _debtAssets) public {
        vm.assume(_debtAssets < type(uint128).max);
        vm.assume(_dp < type(uint128).max);

        uint256 standardDp = 1e18;

        assertEq(SiloMathLib.calculateUtilization(standardDp, 0, _debtAssets), 0);
        assertEq(SiloMathLib.calculateUtilization(standardDp, _collateralAssets, 0), 0);
        assertEq(SiloMathLib.calculateUtilization(0, _collateralAssets, _debtAssets), 0);

        uint256 u = SiloMathLib.calculateUtilization(_dp, _collateralAssets, _debtAssets);
        assertTrue(u <= _dp);
    }

    /*
    forge test -vv --mt test_convertToAssets
    */
    function test_convertToAssets() public {
        uint256 offset = SiloMathLib._DECIMALS_OFFSET_POW;
        uint256 shares;
        uint256 totalAssets;
        uint256 totalShares;

        assertEq(
            SiloMathLib.convertToAssets(shares, totalAssets, totalShares, MathUpgradeable.Rounding.Down),
            0, "all zeros"
        );

        shares = 0;
        totalAssets = 1000;
        totalShares = 1000 * offset;

        assertEq(
            SiloMathLib.convertToAssets(shares, totalAssets, totalShares, MathUpgradeable.Rounding.Down),
            0, "0 shares => 0 assets"
        );

        shares = 1;
        totalAssets = 1;
        totalShares = 1;
        assertEq(
            SiloMathLib.convertToAssets(shares, totalAssets, totalShares, MathUpgradeable.Rounding.Down),
            0, "(1/1), 1 share down => 0 assets"
        );
        assertEq(
            SiloMathLib.convertToAssets(shares, totalAssets, totalShares, MathUpgradeable.Rounding.Up),
            1, "(1/1), 1 share Up => 1 assets"
        );

        totalAssets = 10;
        totalShares = 10 * offset;
        assertEq(
            SiloMathLib.convertToAssets(1, totalAssets, totalShares, MathUpgradeable.Rounding.Down),
            0, "(10/10), 0.01 share down => 0 assets"
        );
        assertEq(
            SiloMathLib.convertToAssets(1, totalAssets, totalShares, MathUpgradeable.Rounding.Up),
            1, "(10/10), 0.01 share Up => 1 assets"
        );
        assertEq(
            SiloMathLib.convertToAssets(100, totalAssets, totalShares, MathUpgradeable.Rounding.Up),
            1, "(10/10), 1.0 share Up => 1 assets"
        );
        assertEq(
            SiloMathLib.convertToAssets(1000, totalAssets, totalShares, MathUpgradeable.Rounding.Up),
            10, "(10/10), 10.00 share Up => 10 assets"
        );
    }

    /*
    forge test -vv --mt test_getAmountsWithInterest
    */
    function test_getAmountsWithInterest() public {
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
        ) = SiloMathLib.getAmountsWithInterest(collateralAssets, debtAssets, rcompInDp, daoFeeInBp, deployerFeeInBp);

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
        ) = SiloMathLib.getAmountsWithInterest(collateralAssets, debtAssets, rcompInDp, daoFeeInBp, deployerFeeInBp);

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
        ) = SiloMathLib.getAmountsWithInterest(collateralAssets, debtAssets, rcompInDp, daoFeeInBp, deployerFeeInBp);

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
        ) = SiloMathLib.getAmountsWithInterest(collateralAssets, debtAssets, rcompInDp, daoFeeInBp, deployerFeeInBp);

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
        ) = SiloMathLib.getAmountsWithInterest(collateralAssets, debtAssets, rcompInDp, daoFeeInBp, deployerFeeInBp);

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
        ) = SiloMathLib.getAmountsWithInterest(collateralAssets, debtAssets, rcompInDp, daoFeeInBp, deployerFeeInBp);

        assertEq(collateralAssetsWithInterest, 2e18, "collateralAssetsWithInterest - no debt, no interest");
        assertEq(debtAssetsWithInterest, 0, "debtAssetsWithInterest - no debt, no interest");
        assertEq(daoAndDeployerFees, 0, "daoAndDeployerFees - no debt, no interest");
        assertEq(accruedInterest, 0, "accruedInterest - no debt, no interest");
    }
}
