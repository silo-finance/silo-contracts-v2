// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IInterestRateModel} from "silo-core/contracts/interfaces/IInterestRateModel.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {AssetTypes} from "silo-core/contracts/lib/AssetTypes.sol";

import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";
import {MintableToken} from "../_common/MintableToken.sol";


/*
    forge test -vv --ffi --mc LiquidationCall1TokenTest
*/
contract LiquidationCall1TokenTest is SiloLittleHelper, Test {
    using SiloLensLib for ISilo;

    address constant BORROWER = address(0x123);
    uint256 constant COLLATERAL = 10e18;
    uint256 constant DEBT = 7.5e18;
    bool constant SAME_TOKEN = true;

    ISiloConfig siloConfig;

    event LiquidationCall(address indexed liquidator, bool receiveSToken);
    error SenderNotSolventAfterTransfer();

    function setUp() public {
        siloConfig = _setUpLocalFixture();

        // we cresting debt on silo1, because lt there is 85 and in silo0 95, so it is easier to test because of dust
        _depositCollateral(COLLATERAL, BORROWER, !SAME_TOKEN);
        vm.prank(BORROWER);
        silo0.borrow(DEBT, BORROWER, BORROWER, SAME_TOKEN);

        assertEq(token0.balanceOf(address(this)), 0, "liquidation should have no collateral");
        assertEq(token0.balanceOf(address(silo0)), COLLATERAL - DEBT, "silo0 has only 2.5 debt token (10 - 7.5)");

        assertEq(siloConfig.getConfig(address(silo0)).liquidationFee, 0.05e18, "liquidationFee1");
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_UnexpectedCollateralToken
    */
    function test_liquidationCall_UnexpectedCollateralToken_1token() public {
        uint256 debtToCover;
        bool receiveSToken;

        vm.expectRevert(IPartialLiquidation.UnexpectedCollateralToken.selector);
        partialLiquidation.liquidationCall(
            address(silo0), address(token1), address(token1), BORROWER, debtToCover, receiveSToken
        );

        vm.expectRevert(IPartialLiquidation.UnexpectedCollateralToken.selector);
        partialLiquidation.liquidationCall(
            address(silo0), address(token1), address(token0), BORROWER, debtToCover, receiveSToken
        );
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_UnexpectedDebtToken
    */
    function test_liquidationCall_UnexpectedDebtToken_1token() public {
        uint256 debtToCover;
        bool receiveSToken;

        vm.expectRevert(IPartialLiquidation.UnexpectedDebtToken.selector);
        partialLiquidation.liquidationCall(
            address(silo0), address(token0), address(token1), BORROWER, debtToCover, receiveSToken
        );
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_NoDebtToCover_whenZero
    */
    function test_liquidationCall_NoDebtToCover_whenZero_1token() public {
        uint256 debtToCover;
        bool receiveSToken;

        vm.expectRevert(IPartialLiquidation.NoDebtToCover.selector);

        partialLiquidation.liquidationCall(
            address(silo0), address(token0), address(token0), BORROWER, debtToCover, receiveSToken
        );
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_NoDebtToCover_whenUserSolvent
    */
    function test_liquidationCall_NoDebtToCover_whenUserSolvent_1token() public {
        uint256 debtToCover = 1e18;
        bool receiveSToken;

        vm.expectRevert(IPartialLiquidation.NoDebtToCover.selector);

        partialLiquidation.liquidationCall(
            address(silo0), address(token0), address(token0), BORROWER, debtToCover, receiveSToken
        );
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_revert_noDebt
    */
    function test_liquidationCall_revert_noDebt_1token() public {
        address userWithoutDebt = address(1);
        uint256 debtToCover = 1e18;
        bool receiveSToken;

        (
            ,, ISiloConfig.DebtInfo memory debtInfo
        ) = siloConfig.getConfigs(address(silo0), userWithoutDebt, 0 /* always 0 for external calls */);

        assertTrue(!debtInfo.debtPresent, "we need user without debt for this test");

        vm.expectRevert(IPartialLiquidation.UserIsSolvent.selector);

        partialLiquidation.liquidationCall(
            address(silo0), address(token0), address(token0), userWithoutDebt, debtToCover, receiveSToken
        );
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_revert_otherSiloDebt
    */
    function test_liquidationCall_revert_otherSiloDebt_1token() public {
        uint256 debtToCover = 1e18;
        bool receiveSToken;

        (
            ,, ISiloConfig.DebtInfo memory debtInfo
        ) = siloConfig.getConfigs(address(silo0), BORROWER, 0 /* always 0 for external calls */);

        assertTrue(debtInfo.debtPresent, "we need user with debt for this test");
        assertTrue(debtInfo.debtInSilo0, "we need debt in silo0");

        vm.expectRevert(ISilo.ThereIsDebtInOtherSilo.selector);

        partialLiquidation.liquidationCall(
            address(silo1), address(token0), address(token0), BORROWER, debtToCover, receiveSToken
        );
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_self
    */
    function test_liquidationCall_self_1token() public {
        uint256 debtToCover = 1e18;
        bool receiveSToken;

        token0.mint(BORROWER, debtToCover);
        vm.prank(BORROWER);
        token0.approve(address(silo0), debtToCover);

        vm.expectEmit(true, true, true, true);
        emit LiquidationCall(BORROWER, receiveSToken);

        vm.prank(BORROWER);

        partialLiquidation.liquidationCall(
            address(silo0), address(token0), address(token0), BORROWER, debtToCover, receiveSToken
        );
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_partial
    */
    function test_liquidationCall_partial_1token() public {
        uint256 debtToCover = 1e5;

        (
            , ISiloConfig.ConfigData memory debtConfig,
        ) = siloConfig.getConfigs(address(silo0), address(0), Hook.NONE);

        (, uint64 interestRateTimestamp0) = silo0.siloData();
        (, uint64 interestRateTimestamp1) = silo1.siloData();
        assertEq(interestRateTimestamp0, 1, "interestRateTimestamp0 is 1 because we deposited and borrow same asset");
        assertEq(interestRateTimestamp1, 0, "interestRateTimestamp1 is 0 because there is no action there");
        assertEq(block.timestamp, 1, "block.timestamp");

        (uint256 collateralToLiquidate, uint256 debtToRepay) = partialLiquidation.maxLiquidation(address(silo0), BORROWER);
        assertEq(collateralToLiquidate, 0, "no collateralToLiquidate yet");
        assertEq(debtToRepay, 0, "no debtToRepay yet");

        emit log_named_decimal_uint("[test] LTV", silo0.getLtv(BORROWER), 16);

        // move forward with time so we can have interests
        uint256 timeForward = 57 days;
        vm.warp(block.timestamp + timeForward);

        (collateralToLiquidate, debtToRepay) = partialLiquidation.maxLiquidation(address(silo0), BORROWER);
        assertGt(collateralToLiquidate, 0, "expect collateralToLiquidate");
        assertGt(debtToRepay, debtToCover, "expect debtToRepay");
        emit log_named_decimal_uint("[test] max debtToRepay", debtToRepay, 18);
        emit log_named_decimal_uint("[test] debtToCover", debtToCover, 18);

        vm.expectCall(address(silo0), abi.encodeWithSelector(ISilo.accrueInterest.selector));
        vm.expectCall(
            address(debtConfig.interestRateModel),
            abi.encodeWithSelector(IInterestRateModel.getCompoundInterestRateAndUpdate.selector)
        );

        emit log_named_decimal_uint("[test] LTV after interest", silo0.getLtv(BORROWER), 16);
        assertEq(silo0.getLtv(BORROWER), 89_4686387330403830, "LTV after interest");
        assertLt(silo0.getLtv(BORROWER), 0.90e18, "expect LTV to be below dust level");
        assertFalse(silo0.isSolvent(BORROWER), "expect BORROWER to be insolvent");

        token0.mint(address(this), debtToCover);
        token0.approve(address(silo0), debtToCover);

        // uint256 collateralWithFee = debtToCover + 0.05e5; // too deep

        { // too deep
            vm.expectCall(
                address(token0),
                abi.encodeWithSelector(IERC20.transfer.selector, address(this), debtToCover + 0.05e5)
            );

            vm.expectCall(
                address(token0),
                abi.encodeWithSelector(IERC20.transferFrom.selector, address(this), address(silo0), debtToCover)
            );

            (
                uint256 withdrawAssetsFromCollateral, uint256 repayDebtAssets
            ) = partialLiquidation.liquidationCall(
                address(silo0), address(token0), address(token0), BORROWER, debtToCover, false /* receiveSToken */
            );

            emit log_named_decimal_uint("[test] withdrawAssetsFromCollateral", withdrawAssetsFromCollateral, 18);
            emit log_named_decimal_uint("[test] repayDebtAssets", repayDebtAssets, 18);
        }

        { // too deep
            emit log_named_decimal_uint("[test] LTV after small liquidation", silo0.getLtv(BORROWER), 16);
            assertEq(silo0.getLtv(BORROWER), 89_4686387330403375, "LTV after small liquidation");
            assertGt(silo0.getLtv(BORROWER), 0, "expect user to be still insolvent after small partial liquidation");
            assertTrue(!silo0.isSolvent(BORROWER), "expect BORROWER to be insolvent after small partial liquidation");

            assertEq(token0.balanceOf(address(this)), debtToCover + 0.05e5, "liquidator should get collateral + 5% fee");

            assertEq(
                token0.balanceOf(address(silo0)),
                COLLATERAL - DEBT - (debtToCover + 0.05e5) + debtToCover,
                "collateral should be transfer to liquidator AND debt token should be repayed"
            );

            assertEq(
                silo0.getCollateralAssets(),
                COLLATERAL - 0.05e5 + 3_298470185392175403,
                "total collateral - liquidation fee + interest"
            );

            assertEq(
                silo0.getDebtAssets(),
                DEBT + 3_298470185392175403 + 1_099490061797425134,
                "debt token + interest + daoFee"
            );
        }

        { // too deep
            (, uint64 interestRateTimestamp0After) = silo0.siloData();
            (, uint64 interestRateTimestamp1After) = silo1.siloData();

            assertEq(interestRateTimestamp0 + timeForward, interestRateTimestamp0After, "interestRateTimestamp #0");
            assertEq(interestRateTimestamp1After, 0, "interestRateTimestamp #1 - no action there");

            (collateralToLiquidate, debtToRepay) = partialLiquidation.maxLiquidation(address(silo0), BORROWER);
            assertGt(collateralToLiquidate, 0, "expect collateralToLiquidate after partial liquidation");
            assertGt(debtToRepay, 0, "expect partial debtToRepay after partial liquidation");

            assertLt(
                debtToRepay,
                DEBT + 3_298470185392175403 + 1_099490061797425134,
                "expect partial debtToRepay to be less than full"
            );

            token0.mint(address(this), debtToRepay);
            token0.approve(address(silo0), debtToRepay);

            vm.expectCall(
                address(token0),
                abi.encodeWithSelector(IERC20.transfer.selector, address(this), 9_203873357727164871)
            );

            vm.expectCall(
                address(token0),
                abi.encodeWithSelector(IERC20.transferFrom.selector, address(this), address(silo0), 8_765593674025871306)
            );

            (
                uint256 withdrawAssetsFromCollateral, uint256 repayDebtAssets
            ) = partialLiquidation.liquidationCall(
                address(silo0), address(token0), address(token0), BORROWER, 2 ** 128, false /* receiveSToken */
            );

            emit log_named_decimal_uint("[test] withdrawAssetsFromCollateral2", withdrawAssetsFromCollateral, 18);
            emit log_named_decimal_uint("[test] repayDebtAssets2", repayDebtAssets, 18);

            emit log_named_decimal_uint("[test] LTV after max liquidation", silo0.getLtv(BORROWER), 16);
            assertGt(silo0.getLtv(BORROWER), 0, "expect some LTV after partial liquidation");
            assertTrue(silo0.isSolvent(BORROWER), "expect BORROWER to be solvent");
        }
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_badDebt_partial_1token_noDepositors
    */
    function test_liquidationCall_badDebt_partial_1token_noDepositors() public {
        uint256 debtToCover = 100e18;
        bool receiveSToken;

        (
            , ISiloConfig.ConfigData memory debtConfig,
        ) = siloConfig.getConfigs(address(silo0), address(0), 0 /* always 0 for external calls */);

        (, uint64 interestRateTimestamp0) = silo0.siloData();
        (, uint64 interestRateTimestamp1) = silo1.siloData();

        // move forward with time so we can have interests

        uint256 timeForward = 120 days;
        vm.warp(block.timestamp + timeForward);
        // expected debt should grow from 7.5 => ~55
        emit log_named_decimal_uint("user ltv", silo0.getLtv(BORROWER), 16);
        assertGt(silo0.getLtv(BORROWER), 1e18, "expect bad debt");

        (
            uint256 collateralToLiquidate, uint256 debtToRepay
        ) = partialLiquidation.maxLiquidation(address(silo0), BORROWER);

        assertEq(silo0.getLiquidity(), 0, "with bad debt and no depositors, no liquidity");
        emit log_named_decimal_uint("collateralToLiquidate", collateralToLiquidate, 18);
        emit log_named_decimal_uint("debtToRepay", debtToRepay, 18);
        assertEq(debtToRepay, silo0.getDebtAssets(), "debtToRepay is max debt");
        assertEq(
            collateralToLiquidate / 100,
            silo0.getCollateralAssets() / 100,
            "we should get all collateral (precision 100)"
        );

        uint256 interest = 48_313643495964160590;
        assertEq(debtToRepay - DEBT, interest, "interests on debt");

        vm.expectCall(address(silo0), abi.encodeWithSelector(ISilo.accrueInterest.selector));
        vm.expectCall(
            address(debtConfig.interestRateModel),
            abi.encodeWithSelector(IInterestRateModel.getCompoundInterestRateAndUpdate.selector)
        );

        // same token liquidation, so `collateralConfig.interestRateModel` is the same as for debt
        // vm.expectCall(
        //    address(collateralConfig.interestRateModel),
        //     abi.encodeWithSelector(IInterestRateModel.getCompoundInterestRateAndUpdate.selector)
        // );

        assertEq(token0.balanceOf(address(this)), 0, "liquidator has no tokens");

        token0.mint(address(this), debtToCover);
        token0.approve(address(silo0), debtToCover);

        partialLiquidation.liquidationCall(
            address(silo0), address(token0), address(token0), BORROWER, debtToCover, receiveSToken
        );

        assertTrue(silo0.isSolvent(BORROWER), "user is solvent after liquidation");
        assertTrue(silo1.isSolvent(BORROWER), "user is solvent after liquidation");

        assertEq(debtConfig.daoFee, 0.15e18, "just checking on daoFee");
        assertEq(debtConfig.deployerFee, 0.10e18, "just checking on deployerFee");

        { // too deep
            uint256 daoAndDeployerFees = interest * (0.15e18 + 0.10e18) / 1e18; // dao fee + deployer fee
            uint256 dust = 4;

            assertEq(
                token0.balanceOf(address(this)),
                debtToCover - debtToRepay + collateralToLiquidate,
                "liquidator should get all borrower collateral, no fee because of bad debt"
            );

            assertEq(
                token0.balanceOf(address(silo0)),
                daoAndDeployerFees + dust,
                "all silo collateral should be transfer to liquidator, fees left"
            );

            silo0.withdrawFees();

            assertEq(token0.balanceOf(address(silo0)), dust, "no balance after withdraw fees");
            assertEq(IShareToken(debtConfig.debtShareToken).totalSupply(), 0, "expected debtShareToken burned");
            assertEq(IShareToken(debtConfig.collateralShareToken).totalSupply(), 0, "expected collateralShareToken burned");
            assertEq(silo0.total(AssetTypes.COLLATERAL), dust, "storage AssetType.Collateral");
            assertEq(silo0.getDebtAssets(), 0, "total debt == 0");
            assertEq(silo0.getCollateralAssets(), dust, "total collateral == 4, dust!");
            assertEq(silo0.getLiquidity(), dust, "getLiquidity == 4, dust!");
        }

        { // too deep
            (, uint64 interestRateTimestamp0After) = silo0.siloData();
            (, uint64 interestRateTimestamp1After) = silo1.siloData();

            assertEq(interestRateTimestamp0 + timeForward, interestRateTimestamp0After, "interestRateTimestamp #0");
            assertEq(interestRateTimestamp1, interestRateTimestamp1After, "interestRateTimestamp #1 (no action here)");
        }
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_badDebt_partial_1token_withDepositors
    */
    function test_liquidationCall_badDebt_partial_1token_withDepositors() public {
        _deposit(1e18, makeAddr("depositor"));

        uint256 debtToCover = 100e18;
        bool receiveSToken;

        (
            , ISiloConfig.ConfigData memory debtConfig,
        ) = siloConfig.getConfigs(address(silo0), address(0), 0 /* always 0 for external calls */);

        (, uint64 interestRateTimestamp0) = silo0.siloData();
        (, uint64 interestRateTimestamp1) = silo1.siloData();

        // move forward with time so we can have interests

        uint256 timeForward = 150 days;
        vm.warp(block.timestamp + timeForward);
        // expected debt should grow from 7.5 => ~73
        emit log_named_decimal_uint("user ltv", silo0.getLtv(BORROWER), 16);
        assertGt(silo0.getLtv(BORROWER), 1e18, "expect bad debt");

        (uint256 collateralToLiquidate, uint256 debtToRepay) = partialLiquidation.maxLiquidation(address(silo0), BORROWER);
        assertEq(silo0.getLiquidity(), 0, "bad debt too big to have liquidity");

        { // too deep
            address depositor = makeAddr("depositor");
            vm.prank(depositor);
            vm.expectRevert();
            silo0.redeem(1, depositor, depositor);
        }

        emit log_named_decimal_uint("collateralToLiquidate", collateralToLiquidate, 18);
        emit log_named_decimal_uint("debtToRepay", debtToRepay, 18);
        assertEq(debtToRepay, silo0.getDebtAssets(), "debtToRepay is max debt");
        assertEq(
            collateralToLiquidate,
            (silo0.getCollateralAssets() - (1e18 + 4_491873366236992444)),
            "we should get all collateral (except depositor deposit + fees), (precision 100)"
        );

        uint256 interest = 65_880809371475889105;
        assertEq(debtToRepay - DEBT, interest, "interests on debt");

        vm.expectCall(address(silo0), abi.encodeWithSelector(ISilo.accrueInterest.selector));
        vm.expectCall(
            address(debtConfig.interestRateModel),
            abi.encodeWithSelector(IInterestRateModel.getCompoundInterestRateAndUpdate.selector)
        );

        // same token liquidation, so `collateralConfig.interestRateModel` is the same as for debt
        // vm.expectCall(
        //    address(collateralConfig.interestRateModel),
        //    abi.encodeWithSelector(IInterestRateModel.getCompoundInterestRateAndUpdate.selector)
        // );

        assertEq(token0.balanceOf(address(this)), 0, "liquidator has no tokens");

        token0.mint(address(this), debtToCover);
        token0.approve(address(silo0), debtToCover);

        partialLiquidation.liquidationCall(
            address(silo0), address(token0), address(token0), BORROWER, debtToCover, receiveSToken
        );

        assertTrue(silo0.isSolvent(BORROWER), "user is solvent after liquidation");
        assertTrue(silo0.isSolvent(BORROWER), "user is solvent after liquidation");

        assertEq(debtConfig.daoFee, 0.15e18, "just checking on daoFee");
        assertEq(debtConfig.deployerFee, 0.10e18, "just checking on deployerFee");

        { // too deep
            uint256 daoAndDeployerFees = interest * (0.15e18 + 0.10e18) / 1e18; // dao fee + deployer fee
            uint256 deposit = 1e18 + 4_491873366236992444;

            assertEq(
                token0.balanceOf(address(this)),
                debtToCover - debtToRepay + collateralToLiquidate,
                "liquidator should get all borrower collateral, no fee because of bad debt"
            );

            assertEq(
                token0.balanceOf(address(silo0)),
                daoAndDeployerFees + deposit,
                "all silo collateral should be transfer to liquidator, fees left and deposit"
            );

            silo0.withdrawFees();

            assertEq(token0.balanceOf(address(silo0)), deposit, "no balance after withdraw fees");
            assertEq(silo0.getDebtAssets(), 0, "total debt == 0");
            assertEq(silo0.getCollateralAssets(), deposit, "total collateral == 4, dust!");
            assertEq(silo0.getLiquidity(), deposit, "getLiquidity == 4, dust!");
        }

        { // too deep
            (, uint64 interestRateTimestamp0After) = silo0.siloData();
            (, uint64 interestRateTimestamp1After) = silo1.siloData();

            assertEq(interestRateTimestamp0 + timeForward, interestRateTimestamp0After, "interestRateTimestamp #0");
            assertEq(interestRateTimestamp1, interestRateTimestamp1After, "interestRateTimestamp #1 (no action here)");
        }

        { // to deep
            address depositor = makeAddr("depositor");
            vm.prank(depositor);
            silo0.redeem(1e18, depositor, depositor);
            assertEq(token0.balanceOf(depositor), 1e18 + 4_491873366236992444 - 5, "depositor can withdraw, left dust");
            assertEq(token0.balanceOf(address(silo0)), 5, "silo should be empty (just dust left)");
        }
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_badDebt_full_withToken
    */
    function test_liquidationCall_badDebt_full_withToken_1token() public {
        bool receiveSToken;
        address liquidator = address(this);
        uint256 dust = 2;

        vm.expectCall(
            address(token0),
            abi.encodeWithSelector(IERC20.transferFrom.selector, liquidator, address(silo0), 30_372197335919815515)
        );

        vm.expectCall(
            address(token0),
            abi.encodeWithSelector(IERC20.transfer.selector, liquidator, 27_154148001939861635)
        );

        _liquidationCall_badDebt_full(receiveSToken);

        assertEq(silo0.getCollateralAssets(), dust, "total collateral (dust)");

        uint256 interest = 30_372197335919815515 - 7.5e18;
        uint256 daoAndDeployerFees = interest * (0.15e18 + 0.10e18) / 1e18; // dao fee + deployer fee

        assertEq(
            token0.balanceOf(address(silo0)),
            daoAndDeployerFees + dust,
            "silo collateral should be transfer to liquidator, fees left"
        );
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_badDebt_full_withSToken
    */
    function test_liquidationCall_badDebt_full_withSToken_1token() public {
        bool receiveSToken = true;
        address liquidator = address(this);

        ISiloConfig.ConfigData memory collateralConfig = siloConfig.getConfig(address(silo0));

        vm.expectCall(
            address(token0),
            abi.encodeWithSelector(
                IERC20.transferFrom.selector, liquidator, address(silo0), 30372197335919815515
            )
        );

        vm.expectCall(
            collateralConfig.collateralShareToken,
            abi.encodeWithSelector(
                IShareToken.forwardTransfer.selector, BORROWER, liquidator, COLLATERAL - 1 // TODO why -1?
            )
        );

        _liquidationCall_badDebt_full(receiveSToken);

        assertEq(
            IShareToken(collateralConfig.collateralShareToken).balanceOf(liquidator),
            COLLATERAL - 1, // TODO check why
            "liquidator should have s-collateral, because of sToken"
        );

        assertEq(
            IShareToken(collateralConfig.collateralShareToken).balanceOf(BORROWER),
            1, // TODO check why
            "BORROWER should have NO s-collateral"
        );
    }

    function _liquidationCall_badDebt_full(bool _receiveSToken) internal {
        uint256 debtToCover = 100e18;
        address liquidator = address(this);

        // move forward with time so we can have interests

        uint256 timeForward = 100 days;
        vm.warp(block.timestamp + timeForward);

        assertGt(silo0.getLtv(BORROWER), 1e18, "[_liquidationCall_badDebt_full] expect bad debt");

        uint256 maxRepay = silo0.maxRepay(BORROWER);
        uint256 interest = 30_372197335919815515 - 7.5e18;
        uint256 daoAndDeployerFees = interest * (0.15e18 + 0.10e18) / 1e18; // dao fee + deployer fee

        (uint256 collateralToLiquidate, uint256 debtToRepay) = partialLiquidation.maxLiquidation(address(silo0), BORROWER);
        emit log_named_decimal_uint("[test] getDebtAssets", silo0.getDebtAssets(), 18);

        assertEq(
            collateralToLiquidate + 2, // dust
            silo0.getCollateralAssets(),
            "expect full collateralToLiquidate on bad debt"
        );

        assertEq(debtToRepay, maxRepay, "debtToRepay == maxRepay");
        assertEq(debtToRepay, silo0.getDebtAssets(), "debtToRepay == all debt");

        token0.mint(liquidator, debtToCover);
        token0.approve(address(silo0), debtToCover);

        emit log_named_decimal_uint("[test] debtToCover", debtToCover, 18);

        if (_receiveSToken) {
            // on bad debt we allow to liquidate any chunk of it
            // however, if we want to receive sTokens, then only full liquidation is possible
            // because we do change check for solvency
            // vm.expectRevert(SenderNotSolventAfterTransfer.selector);
        }

        partialLiquidation.liquidationCall(
            address(silo0), address(token0), address(token0), BORROWER, debtToCover, _receiveSToken
        );

        maxRepay = silo0.maxRepay(BORROWER);
        assertEq(maxRepay, 0, "there will be NO leftover for same token");

        if (_receiveSToken) {
            assertEq(
                token0.balanceOf(address(silo0)),
                COLLATERAL - DEBT + debtToRepay,
                "[_receiveSToken] all collateral available after repay"
            );
        } else {
            assertEq(
                token0.balanceOf(address(silo0)) - 2, // dust
                daoAndDeployerFees,
                "[!_receiveSToken] silo has just fees"
            );

            assertEq(silo0.getCollateralAssets(), 2, "only dust left from collateral");
        }

        assertEq(silo0.getDebtAssets(), 0, "debt is repay");

        if (!_receiveSToken) {
            assertEq(
                token0.balanceOf(liquidator),
                100e18 - debtToRepay + collateralToLiquidate,
                "liquidator should get all collateral because of full liquidation"
            );
        }
    }
}
