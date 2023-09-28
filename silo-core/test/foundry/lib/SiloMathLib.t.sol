// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "silo-core/contracts/lib/SiloMathLib.sol";

// forge test -vv --mc SiloMathLibTest
contract SiloMathLibTest is Test {
    address public config = address(10001);
    address public asset = address(10002);
    address public model = address(10003);

    /*
    forge test -vv --mt test_liquidity
    */
    function test_liquidity() public {
        assertEq(SiloMathLib.liquidity(0, 0), 0);
        assertEq(SiloMathLib.liquidity(100, 10), 90);
        assertEq(SiloMathLib.liquidity(1e18, 1), 999999999999999999);
        assertEq(SiloMathLib.liquidity(1e18, 0.1e18), 0.9e18);
        assertEq(SiloMathLib.liquidity(25000e18, 7999e18), 17001e18);
        assertEq(SiloMathLib.liquidity(25000e18, 30000e18), 0);
    }

    /*
    forge test -vv --mt test_calculateUtilization
    */
    function test_calculateUtilization(uint256 _collateralAssets, uint256 _debtAssets) public {
        uint256 dp = 1e18;

        assertEq(SiloMathLib.calculateUtilization(dp, 1e18, 0.9e18), 0.9e18);
        assertEq(SiloMathLib.calculateUtilization(dp, 1e18, 0.1e18), 0.1e18);
        assertEq(SiloMathLib.calculateUtilization(dp, 10e18, 1e18), 0.1e18);
        assertEq(SiloMathLib.calculateUtilization(dp, 100e18, 25e18), 0.25e18);
        assertEq(SiloMathLib.calculateUtilization(dp, 100e18, 49e18), 0.49e18);
        assertEq(SiloMathLib.calculateUtilization(1e4, 100e18, 49e18), 0.49e4);

        assertEq(SiloMathLib.calculateUtilization(1e18, 0, _debtAssets), 0);
        assertEq(SiloMathLib.calculateUtilization(1e18, _collateralAssets, 0), 0);
        assertEq(SiloMathLib.calculateUtilization(0, _collateralAssets, _debtAssets), 0);
    }

    /*
    forge test -vv --mt test_calculateUtilizationWithMax
    */
    function test_calculateUtilizationWithMax(uint256 _dp, uint256 _collateralAssets, uint256 _debtAssets) public {
        vm.assume(_debtAssets < type(uint128).max);
        vm.assume(_dp < type(uint128).max);

        assertTrue(SiloMathLib.calculateUtilization(_dp, _collateralAssets, _debtAssets) <= _dp);
    }

    /*
    forge test -vv --mt test_convertToAssets
    */
    function test_convertToAssets() public {
        uint256 shares;
        uint256 totalAssets;
        uint256 totalShares;

        assertEq(
            SiloMathLib.convertToAssets(
                shares, totalAssets, totalShares, MathUpgradeable.Rounding.Down, ISilo.AssetType.Collateral
            ),
            0,
            "all zeros"
        );

        shares = 10;

        assertEq(
            SiloMathLib.convertToAssets(
                shares, totalAssets, totalShares, MathUpgradeable.Rounding.Down, ISilo.AssetType.Collateral
            ),
            10,
            "first mint"
        );

        shares = 0;
        totalAssets = 1000;
        totalShares = 1000;

        assertEq(
            SiloMathLib.convertToAssets(
                shares, totalAssets, totalShares, MathUpgradeable.Rounding.Down, ISilo.AssetType.Collateral
            ),
            0,
            "0 shares => 0 assets"
        );

        shares = 333;
        totalAssets = 1000;
        totalShares = 999;

        assertEq(
            SiloMathLib.convertToAssets(
                shares, totalAssets, totalShares, MathUpgradeable.Rounding.Down, ISilo.AssetType.Collateral
            ),
            333,
            "(1000/999) 333 shares down => 333 assets"
        );

        shares = 1;
        totalAssets = 1;
        totalShares = 1;
        assertEq(
            SiloMathLib.convertToAssets(
                shares, totalAssets, totalShares, MathUpgradeable.Rounding.Down, ISilo.AssetType.Collateral
            ),
            1,
            "(1/1), 1 share down => 1 assets"
        );
        assertEq(
            SiloMathLib.convertToAssets(
                shares, totalAssets, totalShares, MathUpgradeable.Rounding.Up, ISilo.AssetType.Collateral
            ),
            1,
            "(1/1), 1 share Up => 1 assets"
        );

        totalAssets = 10;
        totalShares = 10;
        assertEq(
            SiloMathLib.convertToAssets(
                1, totalAssets, totalShares, MathUpgradeable.Rounding.Down, ISilo.AssetType.Collateral
            ),
            1,
            "(10/10), 0.01 share down => 0 assets"
        );
        assertEq(
            SiloMathLib.convertToAssets(
                1, totalAssets, totalShares, MathUpgradeable.Rounding.Up, ISilo.AssetType.Collateral
            ),
            1,
            "(10/10), 0.01 share Up => 1 assets"
        );
        assertEq(
            SiloMathLib.convertToAssets(
                100, totalAssets, totalShares, MathUpgradeable.Rounding.Up, ISilo.AssetType.Collateral
            ),
            100,
            "(10/10), 100 share Up => 100 assets"
        );
        assertEq(
            SiloMathLib.convertToAssets(
                1000, totalAssets, totalShares, MathUpgradeable.Rounding.Up, ISilo.AssetType.Collateral
            ),
            1000,
            "(10/10), 1000 share Up => 1000 assets"
        );
    }

    /*
    forge test -vv --mt test_convertToAssetsForDebt
    */
    function test_convertToAssetsForDebt() public {
        uint256 shares;
        uint256 totalAssets;
        uint256 totalShares;

        assertEq(
            SiloMathLib.convertToAssets(
                shares, totalAssets, totalShares, MathUpgradeable.Rounding.Down, ISilo.AssetType.Debt
            ),
            0,
            "all zeros"
        );

        shares = 100;

        assertEq(
            SiloMathLib.convertToAssets(
                shares, totalAssets, totalShares, MathUpgradeable.Rounding.Down, ISilo.AssetType.Debt
            ),
            100,
            "first mint"
        );

        shares = 0;
        totalAssets = 1000;
        totalShares = 1000;

        assertEq(
            SiloMathLib.convertToAssets(
                shares, totalAssets, totalShares, MathUpgradeable.Rounding.Down, ISilo.AssetType.Debt
            ),
            0,
            "0 shares => 0 assets"
        );

        shares = 333;
        totalAssets = 1000;
        totalShares = 999;

        assertEq(
            SiloMathLib.convertToAssets(
                shares, totalAssets, totalShares, MathUpgradeable.Rounding.Up, ISilo.AssetType.Debt
            ),
            334,
            "(1000/999) 333 shares up => 334 assets"
        );

        shares = 1;
        totalAssets = 1;
        totalShares = 1;
        assertEq(
            SiloMathLib.convertToAssets(
                shares, totalAssets, totalShares, MathUpgradeable.Rounding.Down, ISilo.AssetType.Debt
            ),
            1,
            "(1/1), 1 share down => 1 assets"
        );
        assertEq(
            SiloMathLib.convertToAssets(
                shares, totalAssets, totalShares, MathUpgradeable.Rounding.Up, ISilo.AssetType.Debt
            ),
            1,
            "(1/1), 1 share Up => 1 assets"
        );

        totalAssets = 10;
        totalShares = 10;
        assertEq(
            SiloMathLib.convertToAssets(
                1, totalAssets, totalShares, MathUpgradeable.Rounding.Down, ISilo.AssetType.Debt
            ),
            1,
            "(10/10), 0.01 share down => 1 assets"
        );
        assertEq(
            SiloMathLib.convertToAssets(
                1, totalAssets, totalShares, MathUpgradeable.Rounding.Up, ISilo.AssetType.Debt
            ),
            1,
            "(10/10), 0.01 share Up => 1 assets"
        );

        totalAssets = 1000;
        totalShares = 1000;
        assertEq(
            SiloMathLib.convertToAssets(
                1000, totalAssets, totalShares, MathUpgradeable.Rounding.Down, ISilo.AssetType.Debt
            ),
            1000,
            "(1000/1000), 1000 share Down => 1000 assets"
        );
        assertEq(
            SiloMathLib.convertToAssets(
                1000, totalAssets, totalShares, MathUpgradeable.Rounding.Up, ISilo.AssetType.Debt
            ),
            1000,
            "(10/10), 1000 share Up => 1000 assets"
        );
    }

    /*
    forge test -vv --mt test_convertToShares
    */
    function test_convertToShares() public {
        uint256 assets;
        uint256 totalAssets;
        uint256 totalShares;

        assertEq(
            SiloMathLib.convertToShares(
                assets, totalAssets, totalShares, MathUpgradeable.Rounding.Down, ISilo.AssetType.Collateral
            ),
            0,
            "all zeros"
        );

        assets = 10;

        assertEq(
            SiloMathLib.convertToShares(
                assets, totalAssets, totalShares, MathUpgradeable.Rounding.Down, ISilo.AssetType.Collateral
            ),
            10,
            "first mint"
        );

        assets = 333;
        totalAssets = 999;
        totalShares = 1000;

        assertEq(
            SiloMathLib.convertToShares(
                assets, totalAssets, totalShares, MathUpgradeable.Rounding.Down, ISilo.AssetType.Collateral
            ),
            333,
            "(999/1000) 333 assets down => 333 assets"
        );


        assets = 0;
        totalAssets = 1000;
        totalShares = 1000;

        assertEq(
            SiloMathLib.convertToShares(
                assets, totalAssets, totalShares, MathUpgradeable.Rounding.Down, ISilo.AssetType.Collateral
            ),
            0,
            "0 shares => 0 assets"
        );

        assets = 1;
        totalAssets = 1;
        totalShares = 1;
        assertEq(
            SiloMathLib.convertToShares(
                assets, totalAssets, totalShares, MathUpgradeable.Rounding.Down, ISilo.AssetType.Collateral
            ),
            1,
            "(1/1), 1 share down => 1 assets"
        );
        assertEq(
            SiloMathLib.convertToShares(
                assets, totalAssets, totalShares, MathUpgradeable.Rounding.Up, ISilo.AssetType.Collateral
            ),
            1,
            "(1/1), 1 share Up => 1 assets"
        );

        totalAssets = 10;
        totalShares = 10;
        assertEq(
            SiloMathLib.convertToShares(
                1, totalAssets, totalShares, MathUpgradeable.Rounding.Down, ISilo.AssetType.Collateral
            ),
            1,
            "(10/10), 0.01 share down => 0 assets"
        );
        assertEq(
            SiloMathLib.convertToShares(
                1, totalAssets, totalShares, MathUpgradeable.Rounding.Up, ISilo.AssetType.Collateral
            ),
            1,
            "(10/10), 0.01 share Up => 1 assets"
        );
        assertEq(
            SiloMathLib.convertToShares(
                100, totalAssets, totalShares, MathUpgradeable.Rounding.Up, ISilo.AssetType.Collateral
            ),
            100,
            "(10/10), 100 share Up => 100 assets"
        );
        assertEq(
            SiloMathLib.convertToShares(
                1000, totalAssets, totalShares, MathUpgradeable.Rounding.Up, ISilo.AssetType.Collateral
            ),
            1000,
            "(10/10), 1000 share Up => 1000 assets"
        );
    }

    /*
    forge test -vv --mt test_convertToSharesForDebt
    */
    function test_convertToSharesForDebt() public {
        uint256 assets;
        uint256 totalAssets;
        uint256 totalShares;

        assertEq(
            SiloMathLib.convertToShares(
                assets, totalAssets, totalShares, MathUpgradeable.Rounding.Down, ISilo.AssetType.Debt
            ),
            0,
            "all zeros"
        );

        assets = 10;

        assertEq(
            SiloMathLib.convertToShares(
                assets, totalAssets, totalShares, MathUpgradeable.Rounding.Down, ISilo.AssetType.Debt
            ),
            10,
            "first mint"
        );

        assets = 333;
        totalAssets = 999;
        totalShares = 1000;

        assertEq(
            SiloMathLib.convertToShares(
                assets, totalAssets, totalShares, MathUpgradeable.Rounding.Up, ISilo.AssetType.Debt
            ),
            334,
            "(999/1000) 333 assets up => 334 shares"
        );


        assets = 0;
        totalAssets = 1000;
        totalShares = 1000;

        assertEq(
            SiloMathLib.convertToShares(
                assets, totalAssets, totalShares, MathUpgradeable.Rounding.Down, ISilo.AssetType.Debt
            ),
            0,
            "0 shares => 0 assets"
        );

        assets = 1;
        totalAssets = 1;
        totalShares = 1;
        assertEq(
            SiloMathLib.convertToShares(
                assets, totalAssets, totalShares, MathUpgradeable.Rounding.Down, ISilo.AssetType.Debt
            ),
            1,
            "(1/1), 1 share down => 1 assets"
        );
        assertEq(
            SiloMathLib.convertToShares(
                assets, totalAssets, totalShares, MathUpgradeable.Rounding.Up, ISilo.AssetType.Debt
            ),
            1,
            "(1/1), 1 share Up => 1 assets"
        );

        totalAssets = 10;
        totalShares = 10;
        assertEq(
            SiloMathLib.convertToShares(
                1, totalAssets, totalShares, MathUpgradeable.Rounding.Down, ISilo.AssetType.Debt
            ),
            1,
            "(10/10), 0.01 share down => 0 assets"
        );
        assertEq(
            SiloMathLib.convertToShares(
                1, totalAssets, totalShares, MathUpgradeable.Rounding.Up, ISilo.AssetType.Debt
            ),
            1,
            "(10/10), 0.01 share Up => 1 assets"
        );
        assertEq(
            SiloMathLib.convertToShares(
                100, totalAssets, totalShares, MathUpgradeable.Rounding.Up, ISilo.AssetType.Debt
            ),
            100,
            "(10/10), 100 share Up => 100 assets"
        );
        assertEq(
            SiloMathLib.convertToShares(
                1000, totalAssets, totalShares, MathUpgradeable.Rounding.Up, ISilo.AssetType.Debt
            ),
            1000,
            "(10/10), 1000 share Up => 1000 assets"
        );
    }

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


    /*
    forge test -vv --mt test_calculateMaxBorrow
    */
    function test_calculateMaxBorrowValue() public {
        uint256 configMaxLtv;
        uint256 sumOfBorrowerCollateralValue;
        uint256 borrowerDebtValue;

        assertEq(
            SiloMathLib.calculateMaxBorrowValue(configMaxLtv, sumOfBorrowerCollateralValue, borrowerDebtValue),
            0, "when all zeros"
        );

        configMaxLtv = 0.5e4;
        sumOfBorrowerCollateralValue = 1e18;
        borrowerDebtValue = 0.5e18;

        assertEq(
            SiloMathLib.calculateMaxBorrowValue(configMaxLtv, sumOfBorrowerCollateralValue, borrowerDebtValue),
            0, "when ltv == limit -> zeros"
        );


        configMaxLtv = 0.5e4;
        sumOfBorrowerCollateralValue = 1e18;
        borrowerDebtValue = 1.5e18;

        assertEq(
            SiloMathLib.calculateMaxBorrowValue(configMaxLtv, sumOfBorrowerCollateralValue, borrowerDebtValue),
            0, "when ltv over limit -> zeros"
        );

        configMaxLtv = 0.5e4;
        sumOfBorrowerCollateralValue = 1e18;
        borrowerDebtValue = 0;

        assertEq(
            SiloMathLib.calculateMaxBorrowValue(configMaxLtv, sumOfBorrowerCollateralValue, borrowerDebtValue),
            0.5e18, "when no debt"
        );

        configMaxLtv = 0.5e4;
        sumOfBorrowerCollateralValue = 1e18;
        borrowerDebtValue = 0.1e18;

        assertEq(
            SiloMathLib.calculateMaxBorrowValue(configMaxLtv, sumOfBorrowerCollateralValue, borrowerDebtValue),
            0.4e18, "when below lTV limit"
        );
    }
}
