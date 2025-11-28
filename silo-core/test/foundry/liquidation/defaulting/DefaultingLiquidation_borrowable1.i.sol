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
tests for one way markets, borrowable token is 1
*/
contract DefaultingLiquidationBorrowable1Test is DefaultingLiquidationCommon {
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

        assertGt(
            silo0.getLtv(borrower),
            0,
            "config for this market is less strict, lt ~75%, so we expect here partial liquidation"
        );

        (ISilo collateralSilo, ISilo debtSilo) = _getSilos();

        UserState memory collateralUserAfter = _getUserState(collateralSilo, borrower);
        UserState memory debtUserAfter = _getUserState(debtSilo, borrower);

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

            uint256 debtShares = debtUserBefore.debtShares - debtUserAfter.debtShares;

            assertEq(
                debtSiloBefore.totalDebtShares,
                debtSiloAfter.totalDebtShares + debtShares,
                "[debtSilo] total debt shares canceled by liquidated user debt"
            );
        }

        uint256 collateralLiquidated = 18713351204666493; // hardcoded based on liquidation
        uint256 protectedLiquidated = collateralToLiquidate - collateralLiquidated;

        {
            // borrower checks

            uint256 underestimation = 2;

            assertEq(
                collateralUserBefore.collateralAssets,
                collateralUserAfter.collateralAssets + collateralLiquidated,
                "[collateralUser] borrower collateral taken"
            );

            assertEq(
                collateralUserBefore.protectedAssets,
                collateralUserAfter.protectedAssets + protectedLiquidated + underestimation,
                "[collateralUser] borrower protected taken (more by understimation)"
            );

            assertEq(
                debtUserBefore.debtAssets - debtToRepay, debtUserAfter.debtAssets, "[debtUser] borrower debt canceled"
            );
        }

        {
            // lpProvider checks

            uint256 totalGaugeRewards = 0.018535128812241097829e21; // hardcoded based on logs
            uint256 totalProtectedRewards = 0.495238095238095238096e21; // hardcoded based on logs
            (address protectedShareToken,,) = siloConfig.getShareTokens(address(collateralSilo));

            assertEq(collateralSilo.balanceOf(address(gauge)), totalGaugeRewards, "gauge shares/rewards");

            assertEq(
                IShareToken(protectedShareToken).balanceOf(address(gauge)),
                totalProtectedRewards,
                "protected shares/rewards"
            );

            address lpProvider = makeAddr("lpProvider");
            UserState memory depositorDebt = _getUserState(debtSilo, lpProvider);

            assertEq(
                depositorDebt.collateralAssets,
                0.511385035888068675e18,
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

            // this case is partial liquidation, so we need to repay the debt to exit
            token1.setOnDemand(true);
            debtSilo.repayShares(debtUserAfter.debtShares, borrower);
            token1.setOnDemand(false);

            _assertUserCanExit(debtSilo, IShareToken(protectedShareToken), makeAddr("lpProvider"));
        }
    }

    // CONFIGURATION

    function _getSilos() internal view override returns (ISilo collateralSilo, ISilo debtSilo) {
        collateralSilo = silo0;
        debtSilo = silo1;
    }

    function _getTokens() internal view override returns (address collateralAsset, address debtAsset) {
        collateralAsset = address(token0);
        debtAsset = address(token1);
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
        return SiloConfigsNames.SILO_LOCAL_NO_ORACLE_DEFAULTING0;
    }
}
