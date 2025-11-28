// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {Math} from "openzeppelin5/utils/math/Math.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {IPartialLiquidationByDefaulting} from "silo-core/contracts/interfaces/IPartialLiquidationByDefaulting.sol";
import {ISiloIncentivesController} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";
import {IGaugeHookReceiver} from "silo-core/contracts/interfaces/IGaugeHookReceiver.sol";

import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";

import {DefaultingLiquidationCommon} from "./DefaultingLiquidationCommon.sol";

/*
tests for one way markets, borrowable token is 0
*/
contract DefaultingLiquidationBorrowable0Test is DefaultingLiquidationCommon {
    using SiloLensLib for ISilo;

    function setUp() public override {
        super.setUp();

        (address collateralAsset, address debtAsset) = _getTokens();
        assertNotEq(
            collateralAsset,
            debtAsset,
            "[crosscheck] collateral and debt assets should be different for two assets case"
        );

        (ISilo collateralSilo, ISilo debtSilo) = _getSilos();
        assertNotEq(address(collateralSilo), address(debtSilo), "[crosscheck] silos must be different for this case");
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_defaulting_happyPath -vv
    */
    function test_defaulting_happyPath() public override {
        (
            UserState memory collateralUserBefore,
            UserState memory debtUserBefore,
            SiloState memory collateralSiloBefore,
            SiloState memory debtSiloBefore,
            uint256 collateralToLiquidate,
            uint256 debtToRepay
        ) = _defaulting_happyPath();

        assertEq(silo0.getLtv(borrower), 0, "LT config for this market is 97%, so we expect here full liquidation");

        (ISilo collateralSilo, ISilo debtSilo) = _getSilos();

        UserState memory collateralUserAfter = _getUserState(collateralSilo, borrower);
        UserState memory debtUserAfter = _getUserState(debtSilo, borrower);

        uint256 debtShares = debtUserBefore.debtShares - debtUserAfter.debtShares;

        {
            // silo check

            SiloState memory collateralSiloAfter = _getSiloState(collateralSilo);
            SiloState memory debtSiloAfter = _getSiloState(debtSilo);

            assertEq(
                collateralSiloBefore.totalCollateralShares,
                collateralSiloAfter.totalCollateralShares,
                "[collateralSilo] collateral total shares did not change, we distribute"
            );

            assertEq(
                collateralSiloBefore.totalProtectedShares,
                collateralSiloAfter.totalProtectedShares,
                "[collateralSilo] total protected shares did not change, we distribute"
            );

            assertEq(
                collateralSiloBefore.totalCollateral,
                collateralSiloAfter.totalCollateral,
                "[collateralSilo] collateral total assets did not changed, we distribute"
            );

            assertEq(
                collateralSiloBefore.totalProtected,
                collateralSiloAfter.totalProtected,
                "[collateralSilo] total protected assets did not changed, we distribute"
            );

            assertEq(
                collateralSiloBefore.totalDebt + collateralSiloAfter.totalDebt,
                0,
                "[collateralSilo] total debt on collateral side should not exist"
            );

            assertEq(
                collateralSiloBefore.totalDebtShares + collateralSiloAfter.totalDebtShares,
                0,
                "[collateralSilo] total debt shares on collateral side should not exist"
            );

            assertEq(
                debtSiloBefore.totalCollateralShares,
                debtSiloAfter.totalCollateralShares,
                "[debtSilo] collateral total shares did not change, value did change"
            );

            assertEq(
                debtSiloBefore.totalCollateral,
                debtSiloAfter.totalCollateral + debtToRepay,
                "[debtSilo] total collateralassets deducted"
            );

            assertEq(
                debtSiloBefore.totalProtectedShares,
                debtSiloAfter.totalProtectedShares,
                "[debtSilo] total protected shares must stay protected!"
            );

            assertEq(
                debtSiloBefore.totalProtected,
                debtSiloAfter.totalProtected,
                "[debtSilo] total protected assets must stay protected!"
            );

            assertEq(debtSiloBefore.totalProtected, 1e18, "[debtSilo] total protected assets exists");

            assertEq(
                debtSiloBefore.totalDebt, debtSiloAfter.totalDebt + debtToRepay, "[debtSilo] total debt was canceled"
            );

            assertEq(debtSiloAfter.totalDebt, 0, "[debtSilo] total debt is 0 now, because of full liquidation");

            assertEq(
                debtSiloBefore.totalDebtShares,
                debtSiloAfter.totalDebtShares + debtShares,
                "[debtSilo] total debt shares canceled by liquidated user debt"
            );

            assertEq(
                debtSiloAfter.totalDebtShares, 0, "[debtSilo] total debt shares is 0 now, because of full liquidation"
            );
        }

        uint256 collateralLiquidated = 0.489690721649484537e18; // hardcoded based on liquidation
        uint256 protectedLiquidated = collateralToLiquidate - collateralLiquidated;

        {
            // borrower checks

            uint256 underestimation = 2;

            assertEq(
                collateralUserBefore.collateralAssets,
                collateralLiquidated,
                "[collateralUser] borrower collateral before liquidation"
            );

            assertEq(
                collateralUserAfter.collateralAssets, 0, "[collateralUser] borrower collateral was fully liquidated"
            );

            assertEq(
                collateralUserBefore.protectedAssets,
                protectedLiquidated + underestimation,
                "[collateralUser] borrower protected before liquidation"
            );

            assertEq(
                collateralUserAfter.protectedAssets, 0, "[collateralUser] borrower protected was fully liquidated"
            );

            assertEq(debtUserBefore.debtAssets, debtToRepay, "[debtUser] debt amount canceled");

            assertEq(debtUserAfter.debtAssets, 0, "[debtUser] borrower debt canceled");
        }

        {
            // lpProvider checks

            uint256 totalGaugeRewards = 0.488721037052158825046e21; // hardcoded based on logs
            uint256 totalProtectedRewards = 0.499009900990099009901e21; // hardcoded based on logs
            (address protectedShareToken,,) = siloConfig.getShareTokens(address(collateralSilo));

            assertEq(collateralSilo.balanceOf(address(gauge)), totalGaugeRewards, "gauge shares/rewards");

            assertEq(
                IShareToken(protectedShareToken).balanceOf(address(gauge)),
                totalProtectedRewards,
                "gauge protected shares/rewards"
            );

            address lpProvider = makeAddr("lpProvider");
            UserState memory depositorDebt = _getUserState(debtSilo, lpProvider);

            assertEq(
                depositorDebt.collateralAssets,
                0.019396119484670633e18, // hardcoded based on logs
                "[lpProvider] collateral cut by liquidated collateral"
            );

            assertEq(
                collateralSilo.balanceOf(lpProvider), 0, "[lpProvider] shares are not in lp wallet, they are in gauge"
            );

            assertEq(
                IShareToken(protectedShareToken).balanceOf(lpProvider),
                0,
                "[lpProvider] protected shares are not in lp wallet, they are in gauge"
            );

            vm.prank(lpProvider);
            gauge.claimRewards(lpProvider);

            assertEq(collateralSilo.balanceOf(lpProvider), totalGaugeRewards, "[lpProvider] rewards claimed");

            assertEq(
                IShareToken(protectedShareToken).balanceOf(lpProvider),
                totalProtectedRewards,
                "[lpProvider] protected rewards claimed"
            );

            uint256 collateralAssets = collateralSilo.previewRedeem(totalGaugeRewards);
            uint256 protectedAssets =
                collateralSilo.previewRedeem(totalProtectedRewards, ISilo.CollateralType.Protected);
            uint256 lpAssets = debtSilo.previewRedeem(debtSilo.balanceOf(lpProvider));

            assertGt(
                collateralAssets + protectedAssets + lpAssets,
                1e18,
                "[lpProvider] because there was no bad debt and price is 1:1 we expect total assets as return + interest"
            );
        }

        {
            // protected user check
            assertEq(
                debtSilo.maxWithdraw(makeAddr("protectedUser"), ISilo.CollateralType.Protected),
                1e18,
                "protected user should be able to withdraw all"
            );
        }

        {
            // fees checks - expect whole amount to be transfered
            uint256 revenue = _printRevenue(debtSilo);
            (address daoFeeReceiver, address deployerFeeReceiver) =
                debtSilo.factory().getFeeReceivers(address(debtSilo));

            console2.log("liquidity", debtSilo.getLiquidity());

            _assertWithdrawableFees(debtSilo);
            _assertNoWithdrawableFees(debtSilo);

            _printRevenue(debtSilo);

            uint256 daoBalance = IERC20(debtSilo.asset()).balanceOf(daoFeeReceiver);
            uint256 deployerBalance = IERC20(debtSilo.asset()).balanceOf(deployerFeeReceiver);
            assertEq(daoBalance + deployerBalance, revenue, "dao and deployer should receive whole revenue");
        }

        {
            //exit from debt silo
            (address protectedShareToken,,) = siloConfig.getShareTokens(address(debtSilo));
            _assertUserCanExit(debtSilo, IShareToken(protectedShareToken), makeAddr("protectedUser"));
            _assertUserCanExit(debtSilo, IShareToken(protectedShareToken), makeAddr("lpProvider"));
        }
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_bothLiquidationsResultsMatch_insolvent_fuzz -vv --mc DefaultingLiquidationTwo1Test
    */
    /// forge-config: core_test.fuzz.runs = 100
    function test_bothLiquidationsResultsMatch_insolvent_fuzz(
        uint64 _dropPercentage,
        uint32 _warp,
        uint48 _collateral,
        uint48 _protected
    ) public override {
        _dropPercentage = 0.061e18;
        _warp = 5 days;

        super.test_bothLiquidationsResultsMatch_insolvent_fuzz(_dropPercentage, _warp, _collateral, _protected);
    }

    // CONFIGURATION

    function _getSilos() internal view override returns (ISilo collateralSilo, ISilo debtSilo) {
        collateralSilo = silo1;
        debtSilo = silo0;
    }

    function _getTokens() internal view override returns (address collateralAsset, address debtAsset) {
        collateralAsset = address(token1);
        debtAsset = address(token0);
    }

    function _maxBorrow(address _borrower) internal view override returns (uint256) {
        (, ISilo debtSilo) = _getSilos();

        try debtSilo.maxBorrow(_borrower) returns (uint256 _max) {
            return _max;
        } catch {
            return 0;
        }
    }

    function _executeBorrow(address _borrower, uint256 _amount) internal override returns (bool success) {
        (, ISilo debtSilo) = _getSilos();
        vm.prank(_borrower);

        try debtSilo.borrow(_amount, _borrower, _borrower) {
            success = true;
        } catch {
            success = false;
        }
    }

    function _useConfigName() internal pure override returns (string memory) {
        return SiloConfigsNames.SILO_LOCAL_NO_ORACLE_DEFAULTING1;
    }
}
