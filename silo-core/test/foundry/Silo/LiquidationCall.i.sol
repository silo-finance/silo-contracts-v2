// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloLiquidation} from "silo-core/contracts/interfaces/ISiloLiquidation.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IInterestRateModel} from "silo-core/contracts/interfaces/IInterestRateModel.sol";

import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";
import {MintableToken} from "../_common/MintableToken.sol";


/*
    forge test -vv --ffi --mc LiquidationCallTest
*/
contract LiquidationCallTest is SiloLittleHelper, Test {
    address constant BORROWER = address(0x123);
    uint256 constant COLLATERAL = 10e18;
    uint256 constant DEBT = 7.5e18;

    ISiloConfig siloConfig;

    event LiquidationCall(address indexed liquidator, bool receiveSToken);
    error SenderNotSolventAfterTransfer();

    function setUp() public {
        siloConfig = _setUpLocalFixture();

        _depositForBorrow(8e18, address(1));

        _deposit(COLLATERAL, BORROWER);
        _borrow(DEBT, BORROWER);

        assertEq(token0.balanceOf(address(this)), 0, "liquidation should have no collateral");
        assertEq(token0.balanceOf(address(silo0)), COLLATERAL, "silo0 has borrower collateral");
        assertEq(token1.balanceOf(address(silo1)), 0.5e18, "silo1 has only 0.5 debt token (8 - 7.5)");
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_UnexpectedCollateralToken
    */
    function test_liquidationCall_UnexpectedCollateralToken() public {
        uint256 debtToCover;
        bool receiveSToken;

        vm.expectRevert(ISiloLiquidation.UnexpectedCollateralToken.selector);
        silo1.liquidationCall(address(token1), address(token1), BORROWER, debtToCover, receiveSToken);
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_UnexpectedDebtToken
    */
    function test_liquidationCall_UnexpectedDebtToken() public {
        uint256 debtToCover;
        bool receiveSToken;

        vm.expectRevert(ISiloLiquidation.UnexpectedDebtToken.selector);
        silo1.liquidationCall(address(token0), address(token0), BORROWER, debtToCover, receiveSToken);
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_NoDebtToCover_whenZero
    */
    function test_liquidationCall_NoDebtToCover_whenZero() public {
        uint256 debtToCover;
        bool receiveSToken;

        vm.expectRevert(ISiloLiquidation.NoDebtToCover.selector);
        silo1.liquidationCall(address(token0), address(token1), BORROWER, debtToCover, receiveSToken);
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_NoDebtToCover_whenUserSolvent
    */
    function test_liquidationCall_NoDebtToCover_whenUserSolvent() public {
        uint256 debtToCover = 1e18;
        bool receiveSToken;

        vm.expectRevert(ISiloLiquidation.NoDebtToCover.selector);
        silo1.liquidationCall(address(token0), address(token1), BORROWER, debtToCover, receiveSToken);
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_self
    */
    function test_liquidationCall_self() public {
        uint256 debtToCover = 1e18;
        bool receiveSToken;

        token1.mint(BORROWER, debtToCover);
        vm.prank(BORROWER);
        token1.approve(address(silo1), debtToCover);

        vm.expectEmit(true, true, true, true);
        emit LiquidationCall(BORROWER, receiveSToken);

        vm.prank(BORROWER);
        silo1.liquidationCall(address(token0), address(token1), BORROWER, debtToCover, receiveSToken);
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_partial
    */
    function test_liquidationCall_partial() public {
        uint256 debtToCover = 1e5;
        address liquidator = address(this);

        (
            ISiloConfig.ConfigData memory debtConfig,
            ISiloConfig.ConfigData memory collateralConfig
        ) = siloConfig.getConfigs(address(silo1));

        (, uint64 interestRateTimestamp0) = silo0.siloData();
        (, uint64 interestRateTimestamp1) = silo1.siloData();

        (uint256 collateralToLiquidate, uint256 debtToRepay) = silo1.maxLiquidation(BORROWER);
        assertEq(collateralToLiquidate, 0, "no collateralToLiquidate yet");
        assertEq(debtToRepay, 0, "no debtToRepay yet");

        emit log_named_decimal_uint("[test] LTV", silo1.getLtv(BORROWER), 16);

        // move forward with time so we can have interests
        uint256 timeForward = 7 days;
        vm.warp(block.timestamp + timeForward);

        (collateralToLiquidate, debtToRepay) = silo1.maxLiquidation(BORROWER);
        assertGt(collateralToLiquidate, 0, "expect collateralToLiquidate");
        assertGt(debtToRepay, debtToCover, "expect debtToRepay");

        vm.expectCall(address(silo0), abi.encodeWithSelector(ISilo.accrueInterest.selector));
        vm.expectCall(address(debtConfig.interestRateModel), abi.encodeWithSelector(IInterestRateModel.getCompoundInterestRateAndUpdate.selector));
        vm.expectCall(address(collateralConfig.interestRateModel), abi.encodeWithSelector(IInterestRateModel.getCompoundInterestRateAndUpdate.selector));

        emit log_named_decimal_uint("[test] LTV after interest", silo1.getLtv(BORROWER), 16);
        assertLt(silo1.getLtv(BORROWER), 0.90e18, "expect LTV to be below dust level");
        assertFalse(silo1.isSolvent(BORROWER), "expect BORROWER to be insolvent");

        token1.mint(liquidator, 2 ** 128);
        token1.approve(address(silo1), 2 ** 128);

        silo1.liquidationCall(address(token0), address(token1), BORROWER, debtToCover, false /* receiveSToken */);

        emit log_named_decimal_uint("[test] LTV after small liquidation", silo1.getLtv(BORROWER), 16);
        assertGt(silo1.getLtv(BORROWER), 0, "expect user to be still insolvent LTV after small partial liquidation");
        assertTrue(!silo1.isSolvent(BORROWER), "expect BORROWER to be insolvent after small partial liquidation");

        assertEq(token0.balanceOf(liquidator), 1e5 + 0.05e5, "liquidator should get collateral + 5% fee");
        assertEq(token0.balanceOf(address(silo0)), COLLATERAL - (1e5 + 0.05e5), "silo collateral should be transfer to liquidator");
        assertEq(token1.balanceOf(address(silo1)), 0.5e18 + 1e5, "debt token should be repayed");

        assertEq(token0.balanceOf(liquidator), 1e5 + 0.05e5, "liquidator should get collateral + 5% fee");
        assertEq(token0.balanceOf(address(silo0)), COLLATERAL - (1e5 + 0.05e5), "silo collateral should be transfer to liquidator");
        assertEq(token1.balanceOf(address(silo1)), 0.5e18 + 1e5, "debt token should be repayed");

        assertEq(silo0.getCollateralAssets(), COLLATERAL - (1e5 + 0.05e5), "total collateral");
        assertEq(silo1.getDebtAssets(), 8e18 + 911884679907104475, "debt token + interest");

        (, uint64 interestRateTimestamp0After) = silo0.siloData();
        (, uint64 interestRateTimestamp1After) = silo1.siloData();

        assertEq(interestRateTimestamp0 + timeForward, interestRateTimestamp0After, "interestRateTimestamp #0");
        assertEq(interestRateTimestamp1 + timeForward, interestRateTimestamp1After, "interestRateTimestamp #1");

        (collateralToLiquidate, debtToRepay) = silo1.maxLiquidation(BORROWER);
        assertGt(collateralToLiquidate, 0, "expect collateralToLiquidate after partial liquidation");
        assertGt(debtToRepay, 0, "expect debtToRepay after partial liquidation");

        silo1.liquidationCall(address(token0), address(token1), BORROWER, 2 ** 128, false /* receiveSToken */);

        emit log_named_decimal_uint("[test] LTV after max liquidation", silo1.getLtv(BORROWER), 16);
        assertGt(silo1.getLtv(BORROWER), 0, "expect some LTV after partial liquidation");
        assertTrue(silo1.isSolvent(BORROWER), "expect BORROWER to be solvent");
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_badDebt_partial
    */
    function test_liquidationCall_badDebt_partial() public {
        uint256 debtToCover = 100e18;
        bool receiveSToken;
        address liquidator = address(this);

        (
            ISiloConfig.ConfigData memory debtConfig,
            ISiloConfig.ConfigData memory collateralConfig
        ) = siloConfig.getConfigs(address(silo1));

        (, uint64 interestRateTimestamp0) = silo0.siloData();
        (, uint64 interestRateTimestamp1) = silo1.siloData();

        // move forward with time so we can have interests

        uint256 timeForward = 30 days;
        vm.warp(block.timestamp + timeForward);
        // expected debt should grow from 7.5 => ~70

        (uint256 collateralToLiquidate, uint256 debtToRepay) = silo1.maxLiquidation(BORROWER);
        assertEq(collateralToLiquidate, COLLATERAL, "expect full collateralToLiquidate on bad debt");
        assertGt(debtToRepay, DEBT, "debtToRepay must be higher that original");

        uint256 interest = 61_643835616429440000;
        assertEq(debtToRepay - DEBT, interest, "interests on debt");

        vm.expectCall(address(silo0), abi.encodeWithSelector(ISilo.accrueInterest.selector));
        vm.expectCall(address(debtConfig.interestRateModel), abi.encodeWithSelector(IInterestRateModel.getCompoundInterestRateAndUpdate.selector));
        vm.expectCall(address(collateralConfig.interestRateModel), abi.encodeWithSelector(IInterestRateModel.getCompoundInterestRateAndUpdate.selector));

        token1.mint(liquidator, debtToCover);
        token1.approve(address(silo1), debtToCover);

        silo1.liquidationCall(address(token0), address(token1), BORROWER, debtToCover, receiveSToken);

        assertTrue(silo0.isSolvent(BORROWER), "user is solvent after liquidation");
        assertTrue(silo1.isSolvent(BORROWER), "user is solvent after liquidation");

        assertEq(debtConfig.daoFee, 0.15e18, "just checking on daoFee");
        assertEq(debtConfig.deployerFee, 0.10e18, "just checking on deployerFee");

        uint256 daoAndDeployerFees = interest * (0.15e18 + 0.10e18) / 1e18; // dao fee + deployer fee

        assertEq(
            token0.balanceOf(liquidator), COLLATERAL,
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
        assertEq(token1.balanceOf(liquidator), 100e18 - (7.5e18 + interest), "liquidator did not used all the tokens");

        /*
          _totalCollateral.assets before %   8000000000000000000
          _totalDebt.assets before %         7500000000000000000

          _totalCollateral.assets %         54232876712322080000 (8 + accruedInterest - daoAndDeployerFees)
          _totalDebt.assets %               69143835616429440000 (7.5 + all interest)

          totalFees (daoAndDeployerFees) %  15410958904107360000
          accruedInterest %                 61643835616429440000
        */

        (, uint64 interestRateTimestamp0After) = silo0.siloData();
        (, uint64 interestRateTimestamp1After) = silo1.siloData();

        assertEq(interestRateTimestamp0 + timeForward, interestRateTimestamp0After, "interestRateTimestamp #0");
        assertEq(interestRateTimestamp1 + timeForward, interestRateTimestamp1After, "interestRateTimestamp #1");
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_badDebt_full_withToken
    */
    function test_liquidationCall_badDebt_full_withToken() public {
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
    function test_liquidationCall_badDebt_full_withSToken() public {
        bool receiveSToken = true;
        uint256 collateralSharesToLiquidate = 10e18;
        address liquidator = address(this);

        (, ISiloConfig.ConfigData memory collateralConfig) = siloConfig.getConfigs(address(silo1));

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

        uint256 maxRepay = silo1.maxRepay(BORROWER);

        (uint256 collateralToLiquidate, uint256 debtToRepay) = silo1.maxLiquidation(BORROWER);
        assertEq(collateralToLiquidate, COLLATERAL, "expect full collateralToLiquidate on bad debt");
        assertEq(debtToRepay, maxRepay, "debtToRepay == maxRepay");

        token1.mint(liquidator, debtToCover);
        token1.approve(address(silo1), debtToCover);

        emit log_named_decimal_uint("[test] debtToCover", debtToCover, 18);

        if (_receiveSToken) {
            // on bad debt we allow to liquidate any chunk of it
            // however, if we want to receive sTokens, then only full liquidation is possible
            vm.expectRevert(SenderNotSolventAfterTransfer.selector);
        }
        silo1.liquidationCall(address(token0), address(token1), BORROWER, debtToCover, _receiveSToken);

        if (!_receiveSToken) {
            maxRepay = silo1.maxRepay(BORROWER);
            assertGt(maxRepay, 0, "there will be leftover");
        }

        token1.mint(liquidator, maxRepay);
        token1.increaseAllowance(address(silo1), maxRepay);

        emit log_named_decimal_uint("[test] maxRepay", maxRepay, 18);

        vm.expectCall(
            address(token1),
            abi.encodeWithSelector(IERC20.transferFrom.selector, liquidator, address(silo1), maxRepay)
        );

        silo1.liquidationCall(address(token0), address(token1), BORROWER, maxRepay, _receiveSToken);

        if (_receiveSToken) {
            assertEq(
                token1.balanceOf(address(silo1)),
                maxRepay + 0.5e18,
                "[_receiveSToken] silo has debt token == to cover + original 0.5"
            );
        } else {
            assertEq(
                token1.balanceOf(address(silo1)),
                debtToCover + maxRepay + 0.5e18,
                "[!_receiveSToken] silo has debt token == to cover + original 0.5"
            );
        }

        assertEq(silo1.getDebtAssets(), 0, "debt is repay");
        assertGt(silo1.getCollateralAssets(), 8e18, "collateral ready to borrow (with interests)");

        if (!_receiveSToken) {
            assertEq(token0.balanceOf(address(this)), collateralToLiquidate, "expect to have liquidated collateral");
        }
    }
}
