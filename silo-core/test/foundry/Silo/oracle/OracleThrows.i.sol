// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";

import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";
import {SiloConfigOverride} from "../../_common/fixtures/SiloFixture.sol";
import {SiloFixture} from "../../_common/fixtures/SiloFixture.sol";
import {DummyOracle} from "../../_common/DummyOracle.sol";

/*
    forge test -vv --ffi --mc OracleThrowsTest
*/
contract OracleThrowsTest is SiloLittleHelper, Test {
    ISiloConfig siloConfig;
    address immutable depositor;
    address immutable borrower;

    DummyOracle immutable solvencyOracle0;
    DummyOracle immutable maxLtvOracle0;

    constructor() {
        depositor = makeAddr("Depositor");
        borrower = makeAddr("Borrower");

        token0 = new MintableToken(18);
        token1 = new MintableToken(18);

        solvencyOracle0 = new DummyOracle(1e18, address(token1));
        maxLtvOracle0 = new DummyOracle(1e18, address(token1));

        solvencyOracle0.setExpectBeforeQuote(true);
        maxLtvOracle0.setExpectBeforeQuote(true);

        SiloConfigOverride memory overrides;
        overrides.token0 = address(token0);
        overrides.token1 = address(token1);
        overrides.solvencyOracle0 = address(solvencyOracle0);
        overrides.maxLtvOracle0 = address(maxLtvOracle0);
        overrides.configName = SiloConfigsNames.SILO_LOCAL_BEFORE_CALL;

        SiloFixture siloFixture = new SiloFixture();

        address hook;
        (, silo0, silo1,,, hook) = siloFixture.deploy_local(overrides);
        partialLiquidation = IPartialLiquidation(hook);
    }

    /*
    forge test -vv --ffi --mt test_throwing_oracle
    */
    function test_throwing_oracle_1token() public {
        // we can not test oracle for 1 token, because we not using it for 1 token
        // _throwing_oracle();
    }

    function _throwing_oracle() private {
        uint256 depositAmount = 100e18;
        uint256 borrowAmount = 50e18;

        _deposit(depositAmount, borrower);
        _depositForBorrow(depositAmount, depositor);

        _borrow(borrowAmount, borrower);

        assertEq(token0.balanceOf(borrower), 0);
        assertEq(token0.balanceOf(depositor), 0);
        assertEq(token0.balanceOf(address(silo0)), 100e18, "borrower collateral");

        assertEq(token1.balanceOf(borrower), 50e18, "borrower debt");
        assertEq(token1.balanceOf(depositor), 0);
        assertEq(token1.balanceOf(address(silo1)),50e18, "depositor's deposit");

        vm.warp(block.timestamp + 100 days);
        silo1.accrueInterest();

        solvencyOracle0.breakOracle();
        maxLtvOracle0.breakOracle();

        assertTrue(_withdrawAll(), "expect all tx to be executed till the end");


        assertEq(token0.balanceOf(borrower), 100e18, "borrower got all collateral");
        assertEq(token0.balanceOf(depositor), 0, "depositor didnt had token1");
        assertEq(token0.balanceOf(address(silo0)), 0);

        assertEq(token1.balanceOf(borrower), 0, "borrower repay all debt");
        assertEq(token1.balanceOf(depositor), 100e18 + 726118608081294262, "depositor got deposit + interest");
        assertEq(token1.balanceOf(address(silo1)), 1, "everyone got collateral and fees, rounding policy left");

        assertEq(silo0.getLiquidity(), 0, "silo0.getLiquidity");
        assertEq(silo1.getLiquidity(), 1, "silo1.getLiquidity");
    }

    function _withdrawAll() internal returns (bool success) {
        vm.prank(borrower);
        vm.expectRevert("beforeQuote: oracle is broken");

        ISilo collateralSilo = silo0;
        MintableToken collateralToken = token0;

        collateralSilo.redeem(1, borrower, borrower);
        assertEq(collateralToken.balanceOf(borrower), 0, "borrower can not withdraw even 1 wei when oracle broken");

        uint256 silo1Balance = token1.balanceOf(address(silo1));
        uint256 silo1Liquidity = silo1.getLiquidity();
        emit log_named_decimal_uint("silo1Balance", silo1Balance, 18);
        emit log_named_decimal_uint("silo1Liquidity", silo1Liquidity, 18);
        assertGt(silo1Balance, 0, "expect tokens in silo");
        assertGt(silo1Balance, silo1Liquidity, "we need case with interest");

        vm.prank(depositor);
        vm.expectRevert();
        silo1.withdraw(silo1Liquidity + 1, depositor, depositor);
        assertEq(token1.balanceOf(depositor), 0, "silo has only X tokens available, withdraw for depositor will fail");

        vm.prank(depositor);
        silo1.withdraw(silo1Liquidity, depositor, depositor);
        assertEq(token1.balanceOf(depositor), silo1Liquidity, "depositor can withdraw up to liquidity without oracle");
        assertEq(token1.balanceOf(address(silo1)), silo1Balance - silo1Liquidity, "no available tokens left in silo");

        _repay(10, borrower);
        assertEq(token1.balanceOf(address(silo1)), silo1Balance - silo1Liquidity + 10, "repay without oracle");

        (, address collateralShareToken1, address debtShareToken) = silo1.config().getShareTokens(address(silo1));
        uint256 borrowerDebtShares = IShareToken(debtShareToken).balanceOf(borrower);

        _repayShares(silo1.previewRepayShares(borrowerDebtShares), borrowerDebtShares, borrower);
        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 0, "repay all without oracle - expect no share debt");

        (, address collateralShareToken,) = collateralSilo.config().getShareTokens(address(collateralSilo));

        vm.startPrank(borrower);
        collateralSilo.redeem(IShareToken(collateralShareToken).balanceOf(borrower), borrower, borrower);

        vm.startPrank(depositor);
        silo1.redeem(IShareToken(collateralShareToken1).balanceOf(depositor), depositor, depositor);

        silo1.withdrawFees();

        vm.stopPrank();
        success = true;
    }
}
