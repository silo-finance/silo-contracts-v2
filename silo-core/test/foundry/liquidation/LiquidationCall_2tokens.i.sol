// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IInterestRateModel} from "silo-core/contracts/interfaces/IInterestRateModel.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";

import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";
import {MintableToken} from "../_common/MintableToken.sol";


/*
    forge test -vv --ffi --mc LiquidationCall2TokensTest
*/
contract LiquidationCall2TokensTest is SiloLittleHelper, Test {
    using SiloLensLib for ISilo;
    using SafeCast for uint256;

    address constant DEPOSITOR = address(1);
    address constant BORROWER = address(0x123);
    uint256 constant COLLATERAL = 10e18;
    uint256 constant COLLATERAL_FOR_BORROW = 8e18;
    uint256 constant DEBT = 7.5e18;
    bool constant SAME_TOKEN = true;

    ISiloConfig siloConfig;
    uint256 debtStart;

    event LiquidationCall(address indexed liquidator, bool receiveSToken);
    error SenderNotSolventAfterTransfer();

    function setUp() public {
        siloConfig = _setUpLocalFixture();

        _depositForBorrow(COLLATERAL_FOR_BORROW, DEPOSITOR);
        emit log_named_decimal_uint("COLLATERAL_FOR_BORROW", COLLATERAL_FOR_BORROW, 18);

        _depositCollateral(COLLATERAL, BORROWER, !SAME_TOKEN);
        _borrow(DEBT, BORROWER, !SAME_TOKEN);
        emit log_named_decimal_uint("DEBT", DEBT, 18);
        debtStart = block.timestamp;

        assertEq(token0.balanceOf(address(this)), 0, "liquidation should have no collateral");
        assertEq(token0.balanceOf(address(silo0)), COLLATERAL, "silo0 has borrower collateral");
        assertEq(token1.balanceOf(address(silo1)), 0.5e18, "silo1 has only 0.5 debt token (8 - 7.5)");

        assertEq(siloConfig.getConfig(address(silo0)).liquidationFee, 0.05e18, "liquidationFee0");
        assertEq(siloConfig.getConfig(address(silo1)).liquidationFee, 0.025e18, "liquidationFee1");
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_UnexpectedCollateralToken
    */
    function test_liquidationCall_UnexpectedCollateralToken_2tokens() public {
        uint256 debtToCover;
        bool receiveSToken;

        vm.expectRevert(IPartialLiquidation.UnexpectedCollateralToken.selector);
        partialLiquidation.liquidationCall(
            address(silo1), address(token1), address(token1), BORROWER, debtToCover, receiveSToken
        );


        vm.expectRevert(IPartialLiquidation.UnexpectedCollateralToken.selector);
        partialLiquidation.liquidationCall(
            address(silo1), address(token1), address(token0), BORROWER, debtToCover, receiveSToken
        );
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_UnexpectedDebtToken
    */
    function test_liquidationCall_UnexpectedDebtToken_2tokens() public {
        uint256 debtToCover;
        bool receiveSToken;

        vm.expectRevert(IPartialLiquidation.UnexpectedDebtToken.selector);
        partialLiquidation.liquidationCall(
            address(silo1), address(token0), address(token0), BORROWER, debtToCover, receiveSToken
        );
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_NoDebtToCover_whenZero
    */
    function test_liquidationCall_NoDebtToCover_whenZero_2tokens() public {
        uint256 debtToCover;
        bool receiveSToken;

        vm.expectRevert(IPartialLiquidation.NoDebtToCover.selector);

        partialLiquidation.liquidationCall(
            address(silo1), address(token0), address(token1), BORROWER, debtToCover, receiveSToken
        );
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_NoDebtToCover_whenUserSolvent
    */
    function test_liquidationCall_NoDebtToCover_whenUserSolvent_2tokens() public {
        uint256 debtToCover = 1e18;
        bool receiveSToken;

        vm.expectRevert(IPartialLiquidation.NoDebtToCover.selector);

        partialLiquidation.liquidationCall(
            address(silo1), address(token0), address(token1), BORROWER, debtToCover, receiveSToken
        );
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_revert_noDebt
    */
    function test_liquidationCall_revert_noDebt_2tokens() public {
        address userWithoutDebt = address(1);
        uint256 debtToCover = 1e18;
        bool receiveSToken;

        (
            ,, ISiloConfig.DebtInfo memory debtInfo
        ) = siloConfig.getConfigs(address(silo1), userWithoutDebt, 0 /* always 0 for external calls */);

        assertTrue(!debtInfo.debtPresent, "we need user without debt for this test");

        vm.expectRevert(IPartialLiquidation.UserIsSolvent.selector);

        partialLiquidation.liquidationCall(
            address(silo1), address(token0), address(token1), userWithoutDebt, debtToCover, receiveSToken
        );
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_revert_otherSiloDebt
    */
    function test_liquidationCall_revert_otherSiloDebt_2tokens() public {
        uint256 debtToCover = 1e18;
        bool receiveSToken;

        (
            ,, ISiloConfig.DebtInfo memory debtInfo
        ) = siloConfig.getConfigs(address(silo1), BORROWER, 0 /* always 0 for external calls */);

        assertTrue(debtInfo.debtPresent, "we need user with debt for this test");
        assertTrue(!debtInfo.debtInSilo0, "we need debt in silo1");

        vm.expectRevert(ISilo.ThereIsDebtInOtherSilo.selector);

        partialLiquidation.liquidationCall(
            address(silo0), address(token0), address(token1), BORROWER, debtToCover, receiveSToken
        );
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_self
    */
    function test_liquidationCall_self_2tokens() public {
        uint256 debtToCover = 1e18;
        bool receiveSToken;

        token1.mint(BORROWER, debtToCover);
        vm.prank(BORROWER);
        token1.approve(address(silo1), debtToCover);

        vm.expectEmit(true, true, true, true);
        emit LiquidationCall(BORROWER, receiveSToken);

        vm.prank(BORROWER);

        partialLiquidation.liquidationCall(
            address(silo1), address(token0), address(token1), BORROWER, debtToCover, receiveSToken
        );
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_partial
    */
    function test_liquidationCall_partial_2tokens() public {
        uint256 debtToCover = 1e5;

        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig,
        ) = siloConfig.getConfigs(address(silo1), address(0), 0 /* always 0 for external calls */);

        (, uint64 interestRateTimestamp0) = silo0.siloData();
        (, uint64 interestRateTimestamp1) = silo1.siloData();

        (uint256 collateralToLiquidate, uint256 debtToRepay) = partialLiquidation.maxLiquidation(address(silo1), BORROWER);
        assertEq(collateralToLiquidate, 0, "no collateralToLiquidate yet");
        assertEq(debtToRepay, 0, "no debtToRepay yet");

        emit log_named_decimal_uint("[test] LTV", silo1.getLtv(BORROWER), 16);

        // move forward with time so we can have interests
        uint256 timeForward = 7 days;
        vm.warp(block.timestamp + timeForward);

        (collateralToLiquidate, debtToRepay) = partialLiquidation.maxLiquidation(address(silo1), BORROWER);
        assertGt(collateralToLiquidate, 0, "expect collateralToLiquidate");
        assertGt(debtToRepay, debtToCover, "expect debtToRepay");
        emit log_named_decimal_uint("[test] max debtToRepay", debtToRepay, 18);
        emit log_named_decimal_uint("[test] debtToCover", debtToCover, 18);

        vm.expectCall(address(silo0), abi.encodeWithSelector(ISilo.accrueInterest.selector));
        vm.expectCall(address(debtConfig.interestRateModel), abi.encodeWithSelector(IInterestRateModel.getCompoundInterestRateAndUpdate.selector));
        vm.expectCall(address(collateralConfig.interestRateModel), abi.encodeWithSelector(IInterestRateModel.getCompoundInterestRateAndUpdate.selector));

        emit log_named_decimal_uint("[test] LTV after interest", silo1.getLtv(BORROWER), 16);
        assertEq(silo1.getLtv(BORROWER), 89_1188467990720448, "LTV after interest");
        assertLt(silo1.getLtv(BORROWER), 0.90e18, "expect LTV to be below dust level");
        assertFalse(silo1.isSolvent(BORROWER), "expect BORROWER to be insolvent");

        token1.mint(address(this), 2 ** 128);
        token1.approve(address(silo1), debtToCover);

        // uint256 collateralWithFee = debtToCover + 0.05e5; // too deep

        { // too deep
            vm.expectCall(
                address(token0),
                abi.encodeWithSelector(IERC20.transfer.selector, address(this), debtToCover + 0.05e5)
            );

            vm.expectCall(
                address(token1),
                abi.encodeWithSelector(IERC20.transferFrom.selector, address(this), address(silo1), debtToCover)
            );

            (
                uint256 withdrawAssetsFromCollateral, uint256 repayDebtAssets
            ) = partialLiquidation.liquidationCall(
                address(silo1), address(token0), address(token1), BORROWER, debtToCover, false /* receiveSToken */
            );

            emit log_named_decimal_uint("[test] withdrawAssetsFromCollateral", withdrawAssetsFromCollateral, 18);
            emit log_named_decimal_uint("[test] repayDebtAssets", repayDebtAssets, 18);
        }

        { // too deep
            emit log_named_decimal_uint("[test] LTV after small liquidation", silo1.getLtv(BORROWER), 16);
            assertEq(silo1.getLtv(BORROWER), 89_1188467990719805, "LTV after small liquidation");
            assertGt(silo1.getLtv(BORROWER), 0, "expect user to be still insolvent after small partial liquidation");
            assertTrue(!silo1.isSolvent(BORROWER), "expect BORROWER to be insolvent after small partial liquidation");

            assertEq(token0.balanceOf(address(this)), debtToCover + 0.05e5, "liquidator should get collateral + 5% fee");
            assertEq(token0.balanceOf(address(silo0)), COLLATERAL - (debtToCover + 0.05e5), "silo collateral should be transfer to liquidator");
            assertEq(token1.balanceOf(address(silo1)), 0.5e18 + debtToCover, "debt token should be repayed");

            assertEq(silo0.getCollateralAssets(), COLLATERAL - (debtToCover + 0.05e5), "total collateral");
            assertEq(silo1.getDebtAssets(), 8e18 + 911884679907104475, "debt token + interest");
        }

        { // too deep
            (, uint64 interestRateTimestamp0After) = silo0.siloData();
            (, uint64 interestRateTimestamp1After) = silo1.siloData();

            assertEq(interestRateTimestamp0 + timeForward, interestRateTimestamp0After, "interestRateTimestamp #0");
            assertEq(interestRateTimestamp1 + timeForward, interestRateTimestamp1After, "interestRateTimestamp #1");

            (collateralToLiquidate, debtToRepay) = partialLiquidation.maxLiquidation(address(silo1), BORROWER);
            assertGt(collateralToLiquidate, 0, "expect collateralToLiquidate after partial liquidation");
            assertGt(debtToRepay, 0, "expect debtToRepay after partial liquidation");

            token1.approve(address(silo1), debtToRepay);

            vm.expectCall(
                address(token0),
                abi.encodeWithSelector(IERC20.transfer.selector, address(this), 6_734327389593616466)
            );

            vm.expectCall(
                address(token1),
                abi.encodeWithSelector(IERC20.transferFrom.selector, address(this), address(silo1), 6_413645132946301397)
            );

            (
                uint256 withdrawAssetsFromCollateral, uint256 repayDebtAssets
            ) = partialLiquidation.liquidationCall(
                address(silo1), address(token0), address(token1), BORROWER, 2 ** 128, false /* receiveSToken */
            );

            emit log_named_decimal_uint("[test] withdrawAssetsFromCollateral2", withdrawAssetsFromCollateral, 18);
            emit log_named_decimal_uint("[test] repayDebtAssets2", repayDebtAssets, 18);

            emit log_named_decimal_uint("[test] LTV after max liquidation", silo1.getLtv(BORROWER), 16);
            assertGt(silo1.getLtv(BORROWER), 0, "expect some LTV after partial liquidation");
            assertTrue(silo1.isSolvent(BORROWER), "expect BORROWER to be solvent");
        }
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_DebtToCoverTooSmall_2tokens
    */
    function test_liquidationCall_DebtToCoverTooSmall_2tokens() public {
        assertEq(token1.balanceOf(address(silo1)), silo1.getLiquidity(), "without interest liquidity match balanceOf");

        // move forward with time so we can have interests

        for (uint256 i; i < 7; i++) {
            _timeForwardAndDebug(1 days);
        }

        assertLt(silo1.getLtv(BORROWER), 1e18, "expect insolvency, but not bad debt");
        assertGt(silo1.getLtv(BORROWER), 0.98e18, "expect hi LTV so we force full liquidation");

        (, uint256 debtToRepay) = partialLiquidation.maxLiquidation(address(silo1), BORROWER);

        assertGt(debtToRepay, COLLATERAL_FOR_BORROW, "check for 0 liquidity");
        assertEq(silo1.getLiquidity(), 0, "no liquidity because what was available is less than debt with interest");
        assertEq(debtToRepay, silo1.getDebtAssets(), "debtToRepay is max debt when we forcing full liquidation");

        uint256 debtToCover = debtToRepay - 1; // -1 to check if tx reverts with DebtToCoverTooSmall
        bool receiveSToken;

        vm.expectRevert(IPartialLiquidation.DebtToCoverTooSmall.selector);
        partialLiquidation.liquidationCall(
            address(silo1), address(token0), address(token1), BORROWER, debtToCover, receiveSToken
        );
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_badDebt_partial
    */
    function test_liquidationCall_badDebt_partial_2tokens() public {
        uint256 debtToCover = 100e18;
        bool receiveSToken;

        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig,
        ) = siloConfig.getConfigs(address(silo1), address(0), 0 /* always 0 for external calls */);

        (, uint64 interestRateTimestamp0) = silo0.siloData();
        (, uint64 interestRateTimestamp1) = silo1.siloData();

        // move forward with time so we can have interests

        uint256 timeForward = 30 days;
        vm.warp(block.timestamp + timeForward);
        // expected debt should grow from 7.5 => ~70
        assertGt(silo0.getLtv(BORROWER), 1e18, "expect bad debt");

        (uint256 collateralToLiquidate, uint256 debtToRepay) = partialLiquidation.maxLiquidation(address(silo1), BORROWER);
        assertEq(collateralToLiquidate, COLLATERAL, "expect full collateralToLiquidate on bad debt");
        assertGt(debtToRepay, DEBT, "debtToRepay must be higher that original");

        uint256 interest = 61_643835616429440000;
        assertEq(debtToRepay - DEBT, interest, "interests on debt");

        vm.expectCall(address(silo0), abi.encodeWithSelector(ISilo.accrueInterest.selector));
        vm.expectCall(address(debtConfig.interestRateModel), abi.encodeWithSelector(IInterestRateModel.getCompoundInterestRateAndUpdate.selector));
        vm.expectCall(address(collateralConfig.interestRateModel), abi.encodeWithSelector(IInterestRateModel.getCompoundInterestRateAndUpdate.selector));

        token1.mint(address(this), debtToCover);
        token1.approve(address(partialLiquidation), debtToCover);

        partialLiquidation.liquidationCall(
            address(silo1), address(token0), address(token1), BORROWER, debtToCover, receiveSToken
        );

        assertTrue(silo0.isSolvent(BORROWER), "user is solvent after liquidation");
        assertTrue(silo1.isSolvent(BORROWER), "user is solvent after liquidation");
        assertEq(silo1.getLtv(BORROWER), 0, "user has no debt");

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
                token1.balanceOf(address(silo1)), 0.5e18 + 7.5e18 + interest,
                "silo has debt token fully repay, debt deposit + interest"
            );
            assertEq(
                silo1.getCollateralAssets(), 0.5e18 + 7.5e18 + interest - daoAndDeployerFees,
                "borrowed token + interest"
            );

            assertEq(
                token1.balanceOf(address(this)),
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
            (, uint64 interestRateTimestamp1After) = silo1.siloData();

            assertEq(interestRateTimestamp0 + timeForward, interestRateTimestamp0After, "interestRateTimestamp #0");
            assertEq(interestRateTimestamp1 + timeForward, interestRateTimestamp1After, "interestRateTimestamp #1");
        }
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_badDebt_full_withToken
    */
    function test_liquidationCall_badDebt_full_withToken_2tokens() public {
        bool receiveSToken;
        address liquidator = makeAddr("liquidator");

        vm.expectCall(address(token0), abi.encodeWithSelector(IERC20.transfer.selector, liquidator, 10e18));

        _liquidationCall_badDebt_full(receiveSToken);

        assertEq(token0.balanceOf(liquidator), 10e18, "liquidator should get all collateral because of full liquidation");
        assertEq(silo0.getCollateralAssets(), 0, "total collateral");
        assertEq(token0.balanceOf(address(silo0)), 0, "silo collateral should be transfer to liquidator");
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_badDebt_full_withSToken_2tokens
    */
    function test_liquidationCall_badDebt_full_withSToken_2tokens() public {
        bool receiveSToken = true;
        uint256 collateralSharesToLiquidate = 10e18;
        address liquidator = makeAddr("liquidator");

        (
            ISiloConfig.ConfigData memory collateralConfig, ISiloConfig.ConfigData memory debtConfig,
        ) = siloConfig.getConfigs(address(silo1), BORROWER, 0 /* always 0 for external calls */);

        // IERC20(debtConfig.token).safeTransferFrom(msg.sender, address(this), repayDebtAssets);
        vm.expectCall(
            debtConfig.token,
            abi.encodeWithSelector(
                IERC20.transferFrom.selector, liquidator, address(partialLiquidation), 1e20
            )
        );

        // ISilo(debtConfig.silo).repay(repayDebtAssets, _borrower);
        vm.expectCall(
            debtConfig.token,
            abi.encodeWithSelector(
                IERC20.transferFrom.selector, address(partialLiquidation), address(silo1), 1e20
            )
        );

        // shares -> liquidator (because of receive sToken)
        vm.expectCall(
            collateralConfig.collateralShareToken,
            abi.encodeWithSelector(
                IShareToken.forwardTransferFromNoChecks.selector, BORROWER, liquidator, collateralSharesToLiquidate
            )
        );

        _liquidationCall_badDebt_full(receiveSToken);

        assertEq(token0.balanceOf(liquidator), 0, "liquidator should not have collateral, because of sToken");
        assertEq(silo0.getCollateralAssets(), COLLATERAL, "silo still has collateral assets, because of sToken");
        assertEq(token0.balanceOf(address(silo0)), COLLATERAL, "silo still has collateral balance, because of sToken");
    }

    function _liquidationCall_badDebt_full(bool _receiveSToken) internal {
        uint256 debtToCover = 100e18;
        address liquidator = makeAddr("liquidator");

        // move forward with time so we can have interests

        uint256 timeForward = 50 days;
        vm.warp(block.timestamp + timeForward);

        uint256 maxRepay = silo1.maxRepay(BORROWER);

        (uint256 collateralToLiquidate, uint256 debtToRepay) = partialLiquidation.maxLiquidation(address(silo1), BORROWER);
        assertEq(collateralToLiquidate, COLLATERAL, "expect full collateralToLiquidate on bad debt");
        assertEq(debtToRepay, maxRepay, "debtToRepay == maxRepay");

        token1.mint(liquidator, debtToCover);
        vm.prank(liquidator);
        token1.approve(address(partialLiquidation), debtToCover);

        emit log_named_decimal_uint("[test] debtToCover", debtToCover, 18);

        vm.prank(liquidator);
        partialLiquidation.liquidationCall(
            address(silo1), address(token0), address(token1), BORROWER, debtToCover, _receiveSToken
        );

        if (!_receiveSToken) {
            maxRepay = silo1.maxRepay(BORROWER);
            assertGt(maxRepay, 0, "there will be leftover");
        }

        token1.mint(liquidator, maxRepay);
        vm.prank(liquidator);
        token1.approve(address(partialLiquidation), maxRepay);

        emit log_named_decimal_uint("[test] maxRepay", maxRepay, 18);
        uint256 repayAmount = 10239726027382400000;

        // TODO why maxRepay is 110239726027382400000 and we repay with 10239726027382400000?
        // repay
        vm.expectCall(
            address(token1),
            abi.encodeWithSelector(IERC20.transferFrom.selector, liquidator, address(partialLiquidation), repayAmount)
        );

        vm.expectCall(
            address(token1),
            abi.encodeWithSelector(IERC20.transferFrom.selector, address(partialLiquidation), address(silo1), repayAmount)
        );

        vm.prank(liquidator);
        partialLiquidation.liquidationCall(
            address(silo1), address(token0), address(token1), BORROWER, maxRepay, _receiveSToken
        );

        if (_receiveSToken) {
            assertEq(
                token1.balanceOf(address(silo1)),
                maxRepay + 0.5e18,
                "[_receiveSToken] silo has debt token == to cover + original 0.5"
            );
        } else {
            assertEq(
                token0.balanceOf(liquidator),
                collateralToLiquidate,
                "[!_receiveSToken] expect to have liquidated collateral"
            );

            assertEq(
                token1.balanceOf(address(silo1)),
                debtToCover + maxRepay + 0.5e18,
                "[!_receiveSToken] silo has debt token == to cover + original 0.5"
            );
        }

        assertEq(silo1.getDebtAssets(), 0, "debt is repay");
        assertGt(silo1.getCollateralAssets(), 8e18, "collateral ready to borrow (with interests)");
    }

    function _timeForwardAndDebug(uint256 _time) internal {
        emit log_named_uint("............................move forward days by", _time /60/60/24);

        vm.warp(block.timestamp + _time);

        silo1.accrueInterest();
        silo0.accrueInterest();

        (
            uint256 collateralToLiquidate, uint256 debtToRepay
        ) = partialLiquidation.maxLiquidation(address(silo1), BORROWER);

        (uint192 daoAndDeployerFees,) = silo1.siloData();
        uint256 maxRepay = silo1.maxRepay(BORROWER);
        uint256 interest = maxRepay - DEBT - daoAndDeployerFees;
        uint256 liquidity = silo1.getLiquidity();

        emit log_named_decimal_uint("balance of silo1", token1.balanceOf(address(silo1)), 18);
        emit log_named_decimal_uint("silo1.getLiquidity()", liquidity, 18);

        emit log_named_decimal_uint("daoAndDeployerFees", daoAndDeployerFees, 18);
        emit log_named_decimal_uint("interest", interest, 18);
        emit log_named_decimal_uint("fee + interest", daoAndDeployerFees + interest, 18);

        int256 calculatedLiquidity = (COLLATERAL_FOR_BORROW - DEBT).toInt256() - uint256(daoAndDeployerFees).toInt256();

        emit log_named_decimal_int("(COLLATERAL_FOR_BORROW - DEBT) - fee == liquidity", calculatedLiquidity, 18);

        emit log_named_string(
            "calculatedLiquidity == liquidity",
            calculatedLiquidity == liquidity.toInt256() ? "YES" : "NO"
        );

        emit log_named_decimal_int(
            "liquidity without CAP == deposited + interest - DEBT - fee",
            (COLLATERAL_FOR_BORROW + interest).toInt256() - DEBT.toInt256() - uint256(daoAndDeployerFees).toInt256(),
            18
        );

        emit log_named_decimal_uint("borrower debt", maxRepay, 18);

        uint256 collateralBalanceOfUnderlying = siloLens.collateralBalanceOfUnderlying(
            silo0, address(token0), BORROWER
        );

        emit log_named_decimal_uint("borrower collateral", collateralBalanceOfUnderlying, 18);
        emit log_named_decimal_uint("collateralToLiquidate", collateralToLiquidate, 18);
        emit log_named_decimal_uint("debtToRepay", debtToRepay, 18);
        uint256 daysInDebt = (block.timestamp - debtStart) /60/60/24;
        emit log_named_uint("days in debt", daysInDebt);
        emit log_named_decimal_uint("borrow APY %", (maxRepay - DEBT) * 1e18 / DEBT * 365 / daysInDebt, 16);
        emit log_named_decimal_uint("CAP %", 1e20, 16);

        emit log("-----");
    }
}
