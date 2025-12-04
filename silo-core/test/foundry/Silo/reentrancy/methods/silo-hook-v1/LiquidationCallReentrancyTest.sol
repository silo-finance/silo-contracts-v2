// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {console2} from "forge-std/console2.sol";


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

        MaliciousToken token0 = MaliciousToken(TestStateLib.token0());
        MaliciousToken token1 = MaliciousToken(TestStateLib.token1());

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
        MaliciousToken token0 = MaliciousToken(TestStateLib.token0());
        MaliciousToken token1 = MaliciousToken(TestStateLib.token1());
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

        (, uint256 debtToRepay,) = partialLiquidation.maxLiquidation(borrowerOnReentrancy);

        if (debtToRepay == 0) {
            console2.log("[LiquidationCallReentrancyTest] user not ready for liquidation");
            revert("[LiquidationCallReentrancyTest] user not ready for liquidation");
        }

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
        MaliciousToken token0 = MaliciousToken(TestStateLib.token0());
        MaliciousToken token1 = MaliciousToken(TestStateLib.token1());
        ISilo silo0 = TestStateLib.silo0();
        ISilo silo1 = TestStateLib.silo1();
        // in case we in reentrancy, we can have case with 0 liquidity, so we need to make sure
        // we deposit enough to be able to borrow
        uint256 liquidityForBorrow = 100e18; // + silo1.totalAssets();
        uint256 collateralAmount = 100e18;

        token1.mint(_depositor, liquidityForBorrow);

        vm.prank(_depositor);
        token1.approve(address(silo1), type(uint256).max);

        vm.prank(_depositor);
        silo1.deposit(liquidityForBorrow, _depositor);

        token0.mint(_borrower, collateralAmount);

        vm.prank(_borrower);
        token0.approve(address(silo0), type(uint256).max);

        vm.prank(_borrower);
        silo0.deposit(collateralAmount, _borrower);

        uint256 maxBorrow = silo1.maxBorrow(_borrower);
        
        if (maxBorrow == 0) {
            if (silo1.getLiquidity() == 0) {
                uint256 amount = silo1.getDebtAssets();
                vm.prank(_depositor);
                silo1.deposit(amount, _depositor);
            } else {
                silo0.deposit(collateralAmount, _borrower);
            }

            maxBorrow = silo1.maxBorrow(_borrower);

            console2.log("[LiquidationCallReentrancyTest] we can't borrow");
            revert("[LiquidationCallReentrancyTest] we can't borrow");
        }

        vm.prank(_borrower);
        silo1.borrow(maxBorrow, _borrower, _borrower);

        _makeUserInsolvent(_borrower, _depositor);
    }

    function _makeUserInsolvent(address _borrower, address _depositor) internal {
        ISilo silo0 = TestStateLib.silo0();
        ISilo silo1 = TestStateLib.silo1();

        uint256 maxWithdraw = silo0.maxWithdraw(_borrower);

        if (maxWithdraw != 0) {
            vm.prank(_borrower);
            silo0.withdraw(maxWithdraw, _borrower, _borrower);
        }

        maxWithdraw = silo1.maxWithdraw(_depositor);

        if (maxWithdraw != 0) {
            vm.prank(_depositor);
            silo1.withdraw(maxWithdraw, _depositor, _depositor);
        }

        uint256 y;

        while (silo1.isSolvent(_borrower)) {
            y++;
            vm.warp(block.timestamp + 365 days);
        }

        console2.log(_tabs(4), "[LiquidationCallReentrancyTest] years warp", y);
    }
}
