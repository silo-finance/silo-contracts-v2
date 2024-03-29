// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IInterestRateModel} from "silo-core/contracts/interfaces/IInterestRateModel.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";

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

//        _deposit(8e18, address(1));

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
    forge test -vv --ffi --mt test_liquidationCall_revert_noPosition
    */
    function test_liquidationCall_revert_noPosition_1token() public {
        address userWithoutDebt = address(1);
        uint256 debtToCover = 1e18;
        bool receiveSToken;

        (,, ISiloConfig.PositionInfo memory positionInto) = siloConfig.getConfigs(address(silo0), userWithoutDebt);

        assertTrue(!positionInto.positionOpen, "we need user without position for this test");

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

        (,, ISiloConfig.PositionInfo memory positionInto) = siloConfig.getConfigs(address(silo0), BORROWER);

        assertTrue(positionInto.positionOpen, "we need user with position for this test");
        assertTrue(!positionInto.debtInSilo0, "we need debt in silo0");

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
            ISiloConfig.ConfigData memory debtConfig,
            ISiloConfig.ConfigData memory collateralConfig,
        ) = siloConfig.getConfigs(address(silo0), address(0));

        (, uint64 interestRateTimestamp0) = silo1.siloData();
        (, uint64 interestRateTimestamp1) = silo0.siloData();

        (uint256 collateralToLiquidate, uint256 debtToRepay) = partialLiquidation.maxLiquidation(address(silo0), BORROWER);
        assertEq(collateralToLiquidate, 0, "no collateralToLiquidate yet");
        assertEq(debtToRepay, 0, "no debtToRepay yet");

        emit log_named_decimal_uint("[test] LTV", silo0.getLtv(BORROWER), 16);

        // move forward with time so we can have interests
        uint256 timeForward = 55 days;
        vm.warp(block.timestamp + timeForward);

        (collateralToLiquidate, debtToRepay) = partialLiquidation.maxLiquidation(address(silo0), BORROWER);
        assertGt(collateralToLiquidate, 0, "expect collateralToLiquidate");
        assertGt(debtToRepay, debtToCover, "expect debtToRepay");
        emit log_named_decimal_uint("[test] max debtToRepay", debtToRepay, 18);
        emit log_named_decimal_uint("[test] debtToCover", debtToCover, 18);

        vm.expectCall(address(silo0), abi.encodeWithSelector(ISilo.accrueInterest.selector));
        vm.expectCall(address(debtConfig.interestRateModel), abi.encodeWithSelector(IInterestRateModel.getCompoundInterestRateAndUpdate.selector));
        vm.expectCall(address(collateralConfig.interestRateModel), abi.encodeWithSelector(IInterestRateModel.getCompoundInterestRateAndUpdate.selector));

        emit log_named_decimal_uint("[test] LTV after interest", silo0.getLtv(BORROWER), 16);
        assertEq(silo0.getLtv(BORROWER), 89_1188467990720448, "LTV after interest");
        assertLt(silo0.getLtv(BORROWER), 0.90e18, "expect LTV to be below dust level");
        assertFalse(silo0.isSolvent(BORROWER), "expect BORROWER to be insolvent");

        token0.mint(address(this), 2 ** 128);
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
            assertEq(silo0.getLtv(BORROWER), 89_1188467990719805, "LTV after small liquidation");
            assertGt(silo0.getLtv(BORROWER), 0, "expect user to be still insolvent after small partial liquidation");
            assertTrue(!silo0.isSolvent(BORROWER), "expect BORROWER to be insolvent after small partial liquidation");

            assertEq(token0.balanceOf(address(this)), debtToCover + 0.05e5, "liquidator should get collateral + 5% fee");
            assertEq(token0.balanceOf(address(silo0)), COLLATERAL - (debtToCover + 0.05e5), "silo collateral should be transfer to liquidator");
            assertEq(token0.balanceOf(address(silo0)), 0.5e18 + debtToCover, "debt token should be repayed");

            assertEq(silo0.getCollateralAssets(), COLLATERAL - (debtToCover + 0.05e5), "total collateral");
            assertEq(silo0.getDebtAssets(), 8e18 + 911884679907104475, "debt token + interest");
        }

        { // too deep
            (, uint64 interestRateTimestamp0After) = silo0.siloData();
            (, uint64 interestRateTimestamp1After) = silo0.siloData();

            assertEq(interestRateTimestamp0 + timeForward, interestRateTimestamp0After, "interestRateTimestamp #0");
            assertEq(interestRateTimestamp1 + timeForward, interestRateTimestamp1After, "interestRateTimestamp #1");

            (collateralToLiquidate, debtToRepay) = partialLiquidation.maxLiquidation(address(silo0), BORROWER);
            assertGt(collateralToLiquidate, 0, "expect collateralToLiquidate after partial liquidation");
            assertGt(debtToRepay, 0, "expect debtToRepay after partial liquidation");

            token0.approve(address(silo0), debtToRepay);

            vm.expectCall(
                address(token0),
                abi.encodeWithSelector(IERC20.transfer.selector, address(this), 6_734327389593616466)
            );

            vm.expectCall(
                address(token0),
                abi.encodeWithSelector(IERC20.transferFrom.selector, address(this), address(silo0), 6_413645132946301397)
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
    forge test -vv --ffi --mt test_liquidationCall_badDebt_partial
    */
    function test_liquidationCall_badDebt_partial_1token() public {
        uint256 debtToCover = 100e18;
        bool receiveSToken;

        (
            ISiloConfig.ConfigData memory debtConfig,
            ISiloConfig.ConfigData memory collateralConfig,
        ) = siloConfig.getConfigs(address(silo0), address(0));

        (, uint64 interestRateTimestamp0) = silo0.siloData();
        (, uint64 interestRateTimestamp1) = silo0.siloData();

        // move forward with time so we can have interests

        uint256 timeForward = 30 days;
        vm.warp(block.timestamp + timeForward);
        // expected debt should grow from 7.5 => ~70

        (uint256 collateralToLiquidate, uint256 debtToRepay) = partialLiquidation.maxLiquidation(address(silo0), BORROWER);
        assertEq(collateralToLiquidate, COLLATERAL, "expect full collateralToLiquidate on bad debt");
        assertGt(debtToRepay, DEBT, "debtToRepay must be higher that original");

        uint256 interest = 61_643835616429440000;
        assertEq(debtToRepay - DEBT, interest, "interests on debt");

        vm.expectCall(address(silo0), abi.encodeWithSelector(ISilo.accrueInterest.selector));
        vm.expectCall(address(debtConfig.interestRateModel), abi.encodeWithSelector(IInterestRateModel.getCompoundInterestRateAndUpdate.selector));
        vm.expectCall(address(collateralConfig.interestRateModel), abi.encodeWithSelector(IInterestRateModel.getCompoundInterestRateAndUpdate.selector));

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

            assertEq(
                token0.balanceOf(address(this)), COLLATERAL,
                "liquidator should get all borrower collateral, no fee because of bad debt"
            );

            assertEq(token0.balanceOf(address(silo0)), 0, "all silo collateral should be transfer to liquidator");
            assertEq(silo0.getCollateralAssets(), 0, "total collateral == 0");

            assertEq(
                token0.balanceOf(address(silo0)), 0.5e18 + 7.5e18 + interest,
                "silo has debt token fully repay, debt deposit + interest"
            );
            assertEq(
                silo0.getCollateralAssets(), 0.5e18 + 7.5e18 + interest - daoAndDeployerFees,
                "borrowed token + interest"
            );

            assertEq(
                token0.balanceOf(address(this)),
                100e18 - (7.5e18 + interest),
                "liquidator did not used all the tokens"
            );
        }

        /*
          _totalCollateral.assets before %   8000000000000000000
          _totalDebt.assets before %         7500000000000000000

          _totalCollateral.assets %         54232876712322080000 (8 + accruedInterest - daoAndDeployerFees)
          _totalDebt.assets %               69143835616429440000 (7.5 + all interest)

          totalFees (daoAndDeployerFees) %  15410958904107360000
          accruedInterest %                 61643835616429440000
        */

        { // too deep
            (, uint64 interestRateTimestamp0After) = silo0.siloData();
            (, uint64 interestRateTimestamp1After) = silo0.siloData();

            assertEq(interestRateTimestamp0 + timeForward, interestRateTimestamp0After, "interestRateTimestamp #0");
            assertEq(interestRateTimestamp1 + timeForward, interestRateTimestamp1After, "interestRateTimestamp #1");
        }
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_badDebt_full_withToken
    */
    function test_liquidationCall_badDebt_full_withToken_1token() public {
        bool receiveSToken;
        address liquidator = address(this);

        vm.expectCall(address(token0), abi.encodeWithSelector(IERC20.transfer.selector, liquidator, 10e18));

        _liquidationCall_badDebt_full(receiveSToken);

        assertEq(token0.balanceOf(liquidator), 10e18, "liquidator should get all collateral because of full liquidation");
        assertEq(silo0.getCollateralAssets(), 0, "total collateral");
        assertEq(token0.balanceOf(address(silo0)), 0, "silo collateral should be transfer to liquidator");
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_badDebt_full_withSToken
    */
    function test_liquidationCall_badDebt_full_withSToken_1token() public {
        bool receiveSToken = true;
        uint256 collateralSharesToLiquidate = 10e18;
        address liquidator = address(this);

        (, ISiloConfig.ConfigData memory collateralConfig,) = siloConfig.getConfigs(address(silo0), address(0));

        vm.expectCall(
            collateralConfig.collateralShareToken,
            abi.encodeWithSelector(
                IShareToken.forwardTransfer.selector, BORROWER, liquidator, collateralSharesToLiquidate
            )
        );

        _liquidationCall_badDebt_full(receiveSToken);

        assertEq(token0.balanceOf(liquidator), 0, "liquidator should not have collateral, because of sToken");
        assertEq(silo0.getCollateralAssets(), COLLATERAL, "silo still has collateral assets, because of sToken");
        assertEq(token0.balanceOf(address(silo0)), COLLATERAL, "silo still has collateral balance, because of sToken");
    }

    function _liquidationCall_badDebt_full(bool _receiveSToken) internal {
        uint256 debtToCover = 100e18;
        address liquidator = address(this);

        // move forward with time so we can have interests

        uint256 timeForward = 50 days;
        vm.warp(block.timestamp + timeForward);

        uint256 maxRepay = silo0.maxRepay(BORROWER);

        (uint256 collateralToLiquidate, uint256 debtToRepay) = partialLiquidation.maxLiquidation(address(silo0), BORROWER);
        assertEq(collateralToLiquidate, COLLATERAL, "expect full collateralToLiquidate on bad debt");
        assertEq(debtToRepay, maxRepay, "debtToRepay == maxRepay");

        token0.mint(liquidator, debtToCover);
        token0.approve(address(silo0), debtToCover);

        emit log_named_decimal_uint("[test] debtToCover", debtToCover, 18);

        if (_receiveSToken) {
            // on bad debt we allow to liquidate any chunk of it
            // however, if we want to receive sTokens, then only full liquidation is possible
            vm.expectRevert(SenderNotSolventAfterTransfer.selector);
        }

        partialLiquidation.liquidationCall(
            address(silo0), address(token0), address(token0), BORROWER, debtToCover, _receiveSToken
        );

        if (!_receiveSToken) {
            maxRepay = silo0.maxRepay(BORROWER);
            assertGt(maxRepay, 0, "there will be leftover");
        }

        token0.mint(liquidator, maxRepay);
        token0.increaseAllowance(address(silo0), maxRepay);

        emit log_named_decimal_uint("[test] maxRepay", maxRepay, 18);

        vm.expectCall(
            address(token0),
            abi.encodeWithSelector(IERC20.transferFrom.selector, liquidator, address(silo0), maxRepay)
        );

        partialLiquidation.liquidationCall(
            address(silo0), address(token0), address(token0), BORROWER, maxRepay, _receiveSToken
        );

        if (_receiveSToken) {
            assertEq(
                token0.balanceOf(address(silo0)),
                maxRepay + 0.5e18,
                "[_receiveSToken] silo has debt token == to cover + original 0.5"
            );
        } else {
            assertEq(
                token0.balanceOf(address(silo0)),
                debtToCover + maxRepay + 0.5e18,
                "[!_receiveSToken] silo has debt token == to cover + original 0.5"
            );
        }

        assertEq(silo0.getDebtAssets(), 0, "debt is repay");
        assertGt(silo0.getCollateralAssets(), 8e18, "collateral ready to borrow (with interests)");

        if (!_receiveSToken) {
            assertEq(token0.balanceOf(address(this)), collateralToLiquidate, "expect to have liquidated collateral");
        }
    }
}
