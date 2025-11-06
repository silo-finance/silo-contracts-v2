// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IInterestRateModel} from "silo-core/contracts/interfaces/IInterestRateModel.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {SiloMathLib} from "silo-core/contracts/lib/SiloMathLib.sol";

import {SiloLittleHelper} from "../../../_common/SiloLittleHelper.sol";

/*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mc LiquidationCall999case2tokensTest
*/
contract LiquidationCall999case2tokensTest is SiloLittleHelper, Test {
    using SiloLensLib for ISilo;
    using SafeCast for uint256;

    address immutable DEPOSITOR;
    address immutable BORROWER;
    uint256 constant COLLATERAL = 10e18;
    uint256 constant COLLATERAL_FOR_BORROW = 8e18;
    uint256 constant DEBT = 7.5e18;
    bool constant TO_SILO_1 = true;

    ISiloConfig siloConfig;
    uint256 debtStart;

    ISiloConfig.ConfigData silo0Config;
    ISiloConfig.ConfigData silo1Config;

    error SenderNotSolventAfterTransfer();

    constructor() {
        DEPOSITOR = makeAddr("depositor");
        BORROWER = makeAddr("borrower");
    }

    function setUp() public {
        siloConfig = _setUpLocalFixture();

        _depositForBorrow(COLLATERAL_FOR_BORROW, DEPOSITOR);
        emit log_named_decimal_uint("COLLATERAL_FOR_BORROW", COLLATERAL_FOR_BORROW, 18);

        _depositCollateral(COLLATERAL, BORROWER, !TO_SILO_1);
        _borrow(DEBT, BORROWER);
        emit log_named_decimal_uint("DEBT", DEBT, 18);
        debtStart = block.timestamp;

        assertEq(token0.balanceOf(address(this)), 0, "liquidation should have no collateral");
        assertEq(token0.balanceOf(address(silo0)), COLLATERAL, "silo0 has borrower collateral");
        assertEq(token1.balanceOf(address(silo1)), 0.5e18, "silo1 has only 0.5 debt token (8 - 7.5)");

        silo0Config = siloConfig.getConfig(address(silo0));
        silo1Config = siloConfig.getConfig(address(silo1));

        assertEq(silo0Config.liquidationFee, 0.05e18, "liquidationFee0");
        assertEq(silo1Config.liquidationFee, 0.025e18, "liquidationFee1");

        token0.setOnDemand(true);
        token1.setOnDemand(true);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_liquidationCall_NoCollateralToLiquidate_2tokens
    */
    function test_liquidationCall_NoCollateralToLiquidate_2tokens() public {
        vm.warp(block.timestamp + 365 days);
        uint256 ltv = siloLens.getLtv(silo0, BORROWER);
        assertGt(ltv, 1e18, "expect bad debt for this test");

        // price is 1:1 so we wil use collateral value as max debt to cover
        (uint256 collateralToLiquidate,,) = partialLiquidation.maxLiquidation(BORROWER);

        partialLiquidation.liquidationCall(
            address(token0), address(token1), BORROWER, collateralToLiquidate, false /* receiveSToken */
        );

        ltv = siloLens.getLtv(silo0, BORROWER);
        assertEq(ltv, type(uint256).max, "expect ininite LTV after liquidation");

        vm.expectRevert(IPartialLiquidation.NoCollateralToLiquidate.selector);
        partialLiquidation.liquidationCall(
            address(token0), address(token1), BORROWER, type(uint256).max, false /* receiveSToken */
        );
    }

    /* 
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_liquidationCall_999protected_2tokens

    this is test for 999 case bug 
    scenario is: borrower has protected collateral and 999 regular collateral, 
    on liquidation we use both collaterals but protected can not be translated to assets, so tx reverts
    this test fails for v3.12.0
    */
    function test_liquidationCall_999protected_2tokens() public {
        _liquidationCall_999case(
            ISilo.CollateralType.Protected, _executeLiquidation2tokens, _makeSharesNotWithdrawable2tokens, 365 days
        );
    }

    /* 
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_liquidationCall_999collateral_2tokens
    */
    function test_liquidationCall_999collateral_2tokens() public {
        vm.startPrank(BORROWER);
        silo0.transitionCollateral(silo0.balanceOf(BORROWER), BORROWER, ISilo.CollateralType.Collateral);
        vm.stopPrank();

        _liquidationCall_999case(
            ISilo.CollateralType.Collateral, _executeLiquidation2tokens, _makeSharesNotWithdrawable2tokens, 365 days
        );
    }

    /* 
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_liquidationCall_999collateral_1token
    */
    function test_liquidationCall_999collateral_1token() public {
        // not able to create case where we can have 99 case for collateral shares

        ISilo.CollateralType collateralType = ISilo.CollateralType.Collateral;

        _repay(silo1.maxRepay(BORROWER), BORROWER);

        // we need liquidity for borrow
        _deposit(COLLATERAL, makeAddr("any"));

        vm.startPrank(BORROWER);
        silo0.borrowSameAsset(silo0.maxBorrowSameAsset(BORROWER), BORROWER, BORROWER);
        silo0.transitionCollateral(silo0.balanceOf(BORROWER), BORROWER, ISilo.CollateralType.Collateral);
        vm.stopPrank();

        assertGt(silo0.maxRepay(BORROWER), 0, "we want debt in silo 0");
        assertEq(silo1.maxRepay(BORROWER), 0, "expect no debt on silo1");

        // address borrower2 = makeAddr("borrower2");

        // // second borrow needed because when we liquidate BORROWER, we repay whole debt and
        // _deposit(COLLATERAL, borrower2, ISilo.CollateralType.Protected);
        // vm.startPrank(borrower2);
        // silo0.borrowSameAsset(silo0.maxBorrowSameAsset(borrower2), borrower2, borrower2);
        // vm.stopPrank();

        _liquidationCall_999case(collateralType, _executeLiquidation1token, _makeSharesNotWithdrawable1token, 50 days);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_liquidationCall_999protected_1token
    */
    function test_liquidationCall_999protected_1token() public {
        _repay(silo1.maxRepay(BORROWER), BORROWER);

        // we need liquidity for borrow
        _deposit(COLLATERAL, makeAddr("any"));

        ISilo.CollateralType collateralType = ISilo.CollateralType.Protected;

        vm.startPrank(BORROWER);
        silo0.borrowSameAsset(silo0.maxBorrowSameAsset(BORROWER), BORROWER, BORROWER);
        vm.stopPrank();

        assertGt(silo0.maxRepay(BORROWER), 0, "we want debt in silo 0");
        assertEq(silo1.maxRepay(BORROWER), 0, "expect no debt on silo1");

        // address borrower2 = makeAddr("borrower2");

        // // second borrow needed because when we liquidate BORROWER, we repay whole debt and
        // _deposit(COLLATERAL, borrower2, ISilo.CollateralType.Protected);
        // vm.startPrank(borrower2);
        // silo0.borrowSameAsset(silo0.maxBorrowSameAsset(borrower2), borrower2, borrower2);
        // vm.stopPrank();

        _liquidationCall_999case(
            ISilo.CollateralType.Protected, _executeLiquidation1token, _makeSharesNotWithdrawable1token, 1000 days
        );
    }

    function _liquidationCall_999case(
        ISilo.CollateralType _generateDustForType,
        function() _liquidationCallFn,
        function(ISilo.CollateralType) _makeSharesNotWithdrawableFn,
        uint256 _daysToWarp
    ) internal {
        (IShareToken shareToken, IShareToken otherShareToken) = _generateDustForType == ISilo.CollateralType.Protected
            ? (IShareToken(silo0Config.protectedShareToken), IShareToken(silo0Config.collateralShareToken))
            : (IShareToken(silo0Config.collateralShareToken), IShareToken(silo0Config.protectedShareToken));

        vm.warp(block.timestamp + _daysToWarp);

        // uint256 assetsToForceTransfer = silo0.previewRedeem(borrowerShares, _generateDustForType);

        // if (assetsToForceTransfer > 0) {
        //     emit log_named_uint("assetsToForceTransfer", assetsToForceTransfer);
        //     uint256 sharesToForceTransfer = silo0.previewWithdraw(assetsToForceTransfer, _generateDustForType);
        //     emit log_named_uint("sharesToForceTransfer", sharesToForceTransfer);
        //     vm.prank(address(partialLiquidation));
        //     shareToken.forwardTransferFromNoChecks(BORROWER, makeAddr("random"), borrowerShares - 999);
        // }

        // borrowerShares = shareToken.balanceOf(BORROWER);
        // emit log_named_uint("borrower shares", borrowerShares);
        // assertGt(borrowerShares, 1, "we need to have some shares");
        // assertEq(silo0.previewRedeem(borrowerShares - 1, _generateDustForType), 0, "we need shares to be not withdrawable (2)");

        _makeSharesNotWithdrawableFn(_generateDustForType);

        emit log_named_decimal_uint("borrower other shares", otherShareToken.balanceOf(BORROWER), 18);

        emit log_named_decimal_uint("LTV before liquidation [%]", siloLens.getLtv(silo0, BORROWER), 16);

        uint256 sharesBefore = shareToken.balanceOf(address(this));
        assertEq(sharesBefore, 0, "liquidator should have no shares before liquidation");

        uint256 otherSharesBefore = otherShareToken.balanceOf(address(this));
        assertEq(otherSharesBefore, 0, "liquidator should have no other shares before liquidation");

        (uint256 collateralToLiquidate,,) = partialLiquidation.maxLiquidation(BORROWER);
        emit log_named_decimal_uint("collateralToLiquidate", collateralToLiquidate, 18);
        emit log_named_decimal_uint(
            "collateral to shares",
            silo0.convertToShares(collateralToLiquidate, ISilo.AssetType(uint8(_generateDustForType))),
            18
        );

        console2.log("--- LIQUIDATION CALL ---");

        _liquidationCallFn();

        // assertTrue(silo0.isSolvent(BORROWER), "BORROWER should be solvent");

        uint256 sharesBalanceAfter = shareToken.balanceOf(address(this));
        emit log_named_string("shares token", shareToken.symbol());
        emit log_named_uint("sharesBalanceAfter", sharesBalanceAfter);

        uint256 otherSharesBalanceAfter = otherShareToken.balanceOf(address(this));
        emit log_named_string("other shares token", otherShareToken.symbol());
        emit log_named_uint("otherSharesBalanceAfter", otherSharesBalanceAfter);

        assertGt(sharesBalanceAfter, 0, "liquidator should got dust shares");
        assertEq(
            silo0.previewRedeem(sharesBalanceAfter, _generateDustForType),
            0,
            "liquidator should got non withdrawable shares"
        );

        assertEq(otherSharesBalanceAfter, 0, "liquidator should have no other shares after liquidation");
    }

    function _executeLiquidation2tokens() internal {
        partialLiquidation.liquidationCall(
            address(token0), address(token1), BORROWER, type(uint256).max, false /* receiveSToken */
        );
    }

    function _executeLiquidation1token() internal {
        (uint256 collateralToLiquidate,,) = partialLiquidation.maxLiquidation(BORROWER);

        partialLiquidation.liquidationCall(
            address(token0), address(token0), BORROWER, collateralToLiquidate, false /* receiveSToken */
        );
    }

    function _makeSharesNotWithdrawable1token(ISilo.CollateralType _generateDustForType) internal {
        (IShareToken shareToken, IShareToken otherShareToken) = _generateDustForType == ISilo.CollateralType.Protected
            ? (IShareToken(silo0Config.protectedShareToken), IShareToken(silo0Config.collateralShareToken))
            : (IShareToken(silo0Config.collateralShareToken), IShareToken(silo0Config.protectedShareToken));

        _deposit(1e18, DEPOSITOR, _generateDustForType);
        _deposit(987e18, DEPOSITOR); // collateral

        uint256 borrowerShares = shareToken.balanceOf(BORROWER);
        emit log_named_uint("borrower non witdrawable shares (1)", borrowerShares);

        vm.prank(address(silo0));
        shareToken.burn(DEPOSITOR, DEPOSITOR, 123456789);

        uint256 ratio = silo0.convertToShares(1, ISilo.AssetType(uint8(_generateDustForType)));
        emit log_named_uint("ratio", ratio);
        assertLt(ratio, 1e3, "for this test we expect ratio to be not 1:1");

        vm.prank(BORROWER);
        silo0.mint(ratio + 1, BORROWER, _generateDustForType);

        borrowerShares = shareToken.balanceOf(BORROWER);
        emit log_named_uint("borrower shares (2)", borrowerShares);

        // (uint256 collateralToLiquidate,,) = partialLiquidation.maxLiquidation(BORROWER);
        // uint256 sharesToLiquidate = silo0.previewWithdraw(collateralToLiquidate);

        // vm.prank(address(partialLiquidation));
        // shareToken.forwardTransferFromNoChecks(BORROWER, makeAddr("random"), 1);

        uint256 reduceCollateralValue = otherShareToken.balanceOf(BORROWER) / 2;
        vm.prank(address(partialLiquidation));
        otherShareToken.forwardTransferFromNoChecks(BORROWER, makeAddr("random"), reduceCollateralValue);
        {
            uint256 otherSharesBalance = otherShareToken.balanceOf(BORROWER);
            ISilo.CollateralType otherType = _generateDustForType == ISilo.CollateralType.Collateral
                ? ISilo.CollateralType.Protected
                : ISilo.CollateralType.Collateral;
            uint256 toAssets = silo0.previewRedeem(otherSharesBalance, otherType);
            uint256 toShares = silo0.previewWithdraw(toAssets, otherType);
            emit log_named_decimal_uint("other shares balance", otherSharesBalance, 18);
            emit log_named_decimal_uint("to shares", toShares, 18);

            // uint256 reduce = otherSharesBalance - toShares - 2;
            // emit log_named_uint("reduce", reduce);

            // if (reduce > 0) {
            //     vm.prank(address(partialLiquidation));
            //     otherShareToken.forwardTransferFromNoChecks(BORROWER, makeAddr("random"), reduce);
            // }
        }
        borrowerShares = shareToken.balanceOf(BORROWER);
        emit log_named_uint("borrower non witdrawable shares (3)", borrowerShares);

        assertEq(
            silo0.previewRedeem(borrowerShares, _generateDustForType), 1, "we need shares to generate 1 wei of assets"
        );
        assertEq(
            silo0.previewRedeem(borrowerShares - 1, _generateDustForType),
            0,
            "we need shares to be not withdrawable when rounding down"
        );
    }

    function _makeSharesNotWithdrawable2tokens(ISilo.CollateralType _generateDustForType) internal {
        IShareToken shareToken = _generateDustForType == ISilo.CollateralType.Protected
            ? IShareToken(silo0Config.protectedShareToken)
            : IShareToken(silo0Config.collateralShareToken);

        _deposit(1e18, DEPOSITOR, _generateDustForType);
        _deposit(2, BORROWER, _generateDustForType);

        vm.prank(address(silo0));
        shareToken.burn(DEPOSITOR, DEPOSITOR, 12345678987654321);

        uint256 ratio = silo0.convertToShares(1, ISilo.AssetType(uint8(_generateDustForType)));
        emit log_named_uint("ratio", ratio);
        assertEq(ratio, 999, "for this test we expect ratio to be 999");

        vm.prank(address(partialLiquidation));
        shareToken.forwardTransferFromNoChecks(BORROWER, makeAddr("random"), 1000);

        uint256 borrowerShares = shareToken.balanceOf(BORROWER);
        emit log_named_uint("borrower shares", borrowerShares);

        assertEq(
            silo0.previewRedeem(borrowerShares, _generateDustForType), 1, "we need shares to generate 1 wei of assets"
        );
        assertEq(
            silo0.previewRedeem(borrowerShares - 1, _generateDustForType),
            0,
            "we need shares to be not withdrawable when rounding down"
        );
    }
}
