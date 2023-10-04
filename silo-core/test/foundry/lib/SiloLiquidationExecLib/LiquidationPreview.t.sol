// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "silo-core/contracts/lib/SiloLiquidationExecLib.sol";
import "../../_common/MockOracleQuote.sol";
import "../../_common/SiloLiquidationExecLibImpl.sol";


// forge test -vv --mc LiquidationPreviewTest
contract getExactLiquidationAmountsTest is Test, MockOracleQuote {
    uint256 constant BASIS_POINTS = 1e4;

    // this must match value from SiloLiquidationLib
    uint256 internal constant _LT_LIQUIDATION_MARGIN_IN_BP = 0.9e4; // 90%

    /*
    forge test -vv --mt test_liquidationPreview_noOracle_zero
    */
    function test_liquidationPreview_noOracle_zero() public {
        SiloSolvencyLib.LtvData memory ltvData;
        SiloLiquidationExecLib.LiquidationPreviewParams memory params;

        (uint256 receiveCollateral, uint256 repayDebt) = SiloLiquidationExecLib.liquidationPreview(ltvData, params);
        assertEq(receiveCollateral, 0, "zero collateral on empty values");
        assertEq(repayDebt, 0, "zero debt on empty values");

        ltvData.borrowerCollateralAssets = 1;
        (receiveCollateral, repayDebt) = SiloLiquidationExecLib.liquidationPreview(ltvData, params);
        assertEq(receiveCollateral, 0, "zero collateral on empty debt");
        assertEq(repayDebt, 0, "zero debt on empty debt");

        ltvData.borrowerCollateralAssets = 0;
        ltvData.borrowerDebtAssets = 1;
        (receiveCollateral, repayDebt) = SiloLiquidationExecLib.liquidationPreview(ltvData, params);
        assertEq(receiveCollateral, 0, "zero collateral on empty collateral");
        assertEq(repayDebt, 0, "zero debt on empty collateral");

        ltvData.borrowerCollateralAssets = 1000;
        ltvData.borrowerDebtAssets = 100;
        (receiveCollateral, repayDebt) = SiloLiquidationExecLib.liquidationPreview(ltvData, params);
        assertEq(receiveCollateral, 0, "zero collateral on solvent borrower");
        assertEq(repayDebt, 0, "zero debt on solvent borrower");
    }

    /*
    forge test -vv --mt test_liquidationPreview_zero
    */
    function test_liquidationPreview_zero() public {
        SiloSolvencyLib.LtvData memory ltvData;
        ltvData.collateralOracle = ISiloOracle(COLLATERAL_ORACLE);
        ltvData.debtOracle = ISiloOracle(DEBT_ORACLE);

        SiloLiquidationExecLib.LiquidationPreviewParams memory params;
        params.collateralConfigAsset = COLLATERAL_ASSET;
        params.debtConfigAsset = DEBT_ASSET;

        ltvData.borrowerCollateralAssets = 1;
        ltvData.borrowerDebtAssets = 1;

        _oraclesQuoteMocks(ltvData, 0, 0);

        (uint256 receiveCollateral, uint256 repayDebt) = SiloLiquidationExecLib.liquidationPreview(ltvData, params);
        assertEq(receiveCollateral, 0, "zero collateral on empty values");
        assertEq(repayDebt, 0, "zero debt on empty values");
    }

    /*
    forge test -vv --mt test_liquidationPreview_revert_LiquidationTooBig
    */
    function test_liquidationPreview_revert_LiquidationTooBig() public {
        SiloLiquidationExecLibImpl impl = new SiloLiquidationExecLibImpl();

        SiloSolvencyLib.LtvData memory ltvData;
        ltvData.collateralOracle = ISiloOracle(COLLATERAL_ORACLE);
        ltvData.debtOracle = ISiloOracle(DEBT_ORACLE);
        ltvData.borrowerCollateralAssets = 1e18;
        ltvData.borrowerDebtAssets = 0.8e18;

        SiloLiquidationExecLib.LiquidationPreviewParams memory params;
        params.collateralConfigAsset = COLLATERAL_ASSET;
        params.debtConfigAsset = DEBT_ASSET;
        params.collateralLt = 7999;

        // liquidation margin is 90% of LT => 90% * 79.99% = 71991%
        uint256 maxDebtToCover = 285969296679757229; // this is max debt we can cover
        params.debtToCover = maxDebtToCover;

        _oraclesQuoteMocks(ltvData, 1e18, 0.8000e18); // ltv just above 79%

        // does not revert - counter example first
        (uint256 receiveCollateralAssets, uint256 repayDebtAssets) = impl.liquidationPreview(ltvData, params);
        assertEq(receiveCollateralAssets, maxDebtToCover, "receiveCollateralAssets #1");
        assertEq(repayDebtAssets, maxDebtToCover, "repayDebtAssets #1");

        // more debt should cause revert because of _LT_LIQUIDATION_MARGIN_IN_BP
        params.debtToCover += 1;

        // does not revert for self liquidation - counter example first
        params.selfLiquidation = true;
        (receiveCollateralAssets, repayDebtAssets) = impl.liquidationPreview(ltvData, params);
        assertEq(receiveCollateralAssets, maxDebtToCover + 1, "receiveCollateralAssets #2");
        assertEq(repayDebtAssets, maxDebtToCover + 1, "repayDebtAssets #2");

        params.selfLiquidation = false;
        vm.expectRevert(ISiloLiquidation.LiquidationTooBig.selector);
        impl.liquidationPreview(ltvData, params);
    }

    /*
    forge test -vv --mt test_liquidationPreview_selfLiquidation_whenSolvent
    */
    function test_liquidationPreview_selfLiquidation_whenSolvent() public {
        SiloSolvencyLib.LtvData memory ltvData;
        ltvData.collateralOracle = ISiloOracle(COLLATERAL_ORACLE);
        ltvData.debtOracle = ISiloOracle(DEBT_ORACLE);
        ltvData.borrowerCollateralAssets = 1e18;
        ltvData.borrowerDebtAssets = 1e18;

        SiloLiquidationExecLib.LiquidationPreviewParams memory params;
        params.collateralConfigAsset = COLLATERAL_ASSET;
        params.debtConfigAsset = DEBT_ASSET;
        params.collateralLt = 8000;
        params.debtToCover = 2;

        _oraclesQuoteMocks(ltvData, 1e18, 0.5e18); // ltv 50% - user solvent

        (uint256 receiveCollateral, uint256 repayDebt) = SiloLiquidationExecLib.liquidationPreview(ltvData, params);
        assertEq(receiveCollateral, 0, "no collateral - user is solvent");
        assertEq(repayDebt, 0, "no debt - user is solvent");

        params.selfLiquidation = true;
        (receiveCollateral, repayDebt) = SiloLiquidationExecLib.liquidationPreview(ltvData, params);
        assertEq(receiveCollateral, 1, "some collateral - self-liquidation");
        assertEq(repayDebt, 2, "some debt - self-liquidation");
    }

    /*
    forge test -vv --mt test_liquidationPreview_whenNotSolvent
    */
    function test_liquidationPreview_whenNotSolvent() public {
        SiloSolvencyLib.LtvData memory ltvData;
        ltvData.borrowerCollateralAssets = 1e18;
        ltvData.borrowerDebtAssets = 2e18; // 200% LTV

        SiloLiquidationExecLib.LiquidationPreviewParams memory params;
        params.collateralConfigAsset = COLLATERAL_ASSET;
        params.debtConfigAsset = DEBT_ASSET;
        params.collateralLt = 8000;
        params.debtToCover = 2;

        _oraclesQuoteMocks(ltvData, 1e18, 2e18); // ltv 200% - user NOT solvent

        (uint256 receiveCollateral, uint256 repayDebt) = SiloLiquidationExecLib.liquidationPreview(ltvData, params);
        assertEq(receiveCollateral, 2, "receiveCollateral");
        assertEq(repayDebt, 2, "repayDebt");
    }
}
