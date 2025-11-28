// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {ICrossReentrancyGuard} from "silo-core/contracts/interfaces/ICrossReentrancyGuard.sol";
import {TransientReentrancy} from "silo-core/contracts/hooks/_common/TransientReentrancy.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";
import {MaliciousToken} from "../../MaliciousToken.sol";

contract LiquidationCallReentrancyTest is MethodReentrancyTest {
    address public depositor = makeAddr("DepositorLiquidation");
    address public borrower = makeAddr("BorrowerLiquidation");

    address public depositorOnReentrancy = makeAddr("DepositorLiquidationReentrancy");
    address public borrowerOnReentrancy = makeAddr("BorrowerLiquidationReentrancy");

    function callMethod() external {
        // disable reentrancy check in the test so we will not check it on deposit/borrow
        TestStateLib.disableReentrancy();
        _createInsolventBorrower(depositor, borrower);

        IPartialLiquidation partialLiquidation = IPartialLiquidation(TestStateLib.hookReceiver());

        uint256 collateralToLiquidate;
        uint256 debtToRepay;

        (collateralToLiquidate, debtToRepay,) = partialLiquidation.maxLiquidation(borrower);

        MaliciousToken token1 = MaliciousToken(TestStateLib.token1());
        MaliciousToken token0 = MaliciousToken(TestStateLib.token0());

        token1.mint(borrower, debtToRepay); // mint extra

        vm.prank(borrower);
        token1.approve(address(partialLiquidation), type(uint256).max);

        // Enable reentrancy to check in the test so we can check it during the liquidation.
        TestStateLib.enableReentrancy();
        TestStateLib.setReenterViaLiquidationCall(true);

        bool receiveSTokens = true;

        vm.prank(borrower);
        partialLiquidation.liquidationCall(address(token0), address(token1), borrower, debtToRepay, receiveSTokens);

        TestStateLib.setReenterViaLiquidationCall(false);
    }

    function verifyReentrancy() external {
        ISiloConfig siloConfig = TestStateLib.siloConfig();
        MaliciousToken token1 = MaliciousToken(TestStateLib.token1());
        MaliciousToken token0 = MaliciousToken(TestStateLib.token0());
        address hookReceiver = TestStateLib.hookReceiver();
        bool receiveSTokens = true;

        // Disable reentrancy to create insolvent borrower.
        vm.prank(hookReceiver);
        siloConfig.turnOffReentrancyProtection();

        _createInsolventBorrower(depositorOnReentrancy, borrowerOnReentrancy);

        // Enable reentrancy to test liquidation with insolvent borrower.
        // We return to the previous state.
        vm.prank(hookReceiver);
        siloConfig.turnOnReentrancyProtection();

        IPartialLiquidation partialLiquidation = IPartialLiquidation(hookReceiver);

        uint256 debtToRepay;

        (, debtToRepay,) = partialLiquidation.maxLiquidation(borrowerOnReentrancy);

        vm.prank(borrowerOnReentrancy);

        if (TestStateLib.reenterViaLiquidationCall()) {
            vm.expectRevert(TransientReentrancy.ReentrancyGuardReentrantCall.selector);
        } else {
            vm.expectRevert(ICrossReentrancyGuard.CrossReentrantCall.selector);
        }

        partialLiquidation.liquidationCall(
            address(token0), address(token1), borrowerOnReentrancy, debtToRepay, receiveSTokens
        );
    }

    function methodDescription() external pure returns (string memory description) {
        description = "liquidationCall(address,address,address,uint256,bool)";
    }

    function _createInsolventBorrower(address _depositor, address _borrower) internal {
        MaliciousToken token1 = MaliciousToken(TestStateLib.token1());
        MaliciousToken token0 = MaliciousToken(TestStateLib.token0());
        ISilo silo1 = TestStateLib.silo1();
        ISilo silo0 = TestStateLib.silo0();
        uint256 liquidityForBorrow = 100e18;
        uint256 collateralAmount = liquidityForBorrow;

        token1.mint(_depositor, liquidityForBorrow);

        vm.prank(_depositor);
        token1.approve(address(silo1), liquidityForBorrow);

        vm.prank(_depositor);
        silo1.deposit(liquidityForBorrow, _depositor);

        token0.mint(_borrower, collateralAmount);

        vm.prank(_borrower);
        token0.approve(address(silo0), collateralAmount);

        vm.prank(_borrower);
        silo0.deposit(collateralAmount, _borrower);

        uint256 siloBalance = token1.balanceOf(address(silo1));
        uint256 maxBorrow = silo1.maxBorrow(_borrower);

        if (maxBorrow == 0) {
            liquidityForBorrow *= 200;

            token1.mint(_depositor, liquidityForBorrow);

            vm.prank(_depositor);
            token1.approve(address(silo1), liquidityForBorrow);

            vm.prank(_depositor);
            silo1.deposit(liquidityForBorrow, _depositor);

            maxBorrow = silo1.maxBorrow(_borrower);
        }

        assertGt(maxBorrow, 0, "maxBorrow is still 0, something is wrong - check json config for silo");

        if (maxBorrow > siloBalance) {
            maxBorrow = siloBalance;
        }

        assertGt(maxBorrow, 0.2e18, "maxBorrow is less than 0.2e18");

        maxBorrow -= 0.2e18;

        vm.prank(_borrower);
        silo1.borrow(maxBorrow, _borrower, _borrower);

        _makeUserInsolvent(_borrower);
    }

    function _makeUserInsolvent(address _borrower) internal {
        ISilo silo1 = TestStateLib.silo1();

        bool isSolvent = silo1.isSolvent(_borrower);

        while (isSolvent) {
            vm.warp(block.timestamp + 200 days);

            isSolvent = silo1.isSolvent(_borrower);
        }
    }
}
