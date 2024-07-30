// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {ICrossReentrancyGuard} from "silo-core/contracts/interfaces/ICrossReentrancyGuard.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";
import {MaliciousToken} from "../../MaliciousToken.sol";

contract LiquidationCallReentrancyTest is MethodReentrancyTest {
    address public depositor = makeAddr("Depositor liquidation");
    address public borrower = makeAddr("Borrower liquidation");

    function callMethod() external {
        _createInsolventBorrower();

        IPartialLiquidation partialLiquidation = IPartialLiquidation(TestStateLib.hookReceiver());

        // liquidation
        vm.warp(block.timestamp + 170 days);

        uint256 collateralToLiquidate;
        uint256 debtToRepay;

        (collateralToLiquidate, debtToRepay) = partialLiquidation.maxLiquidation(borrower);

        MaliciousToken token0 = MaliciousToken(TestStateLib.token0());
        MaliciousToken token1 = MaliciousToken(TestStateLib.token1());

        token0.mint(borrower, debtToRepay); // mint extra

        vm.prank(borrower);
        token0.approve(address(partialLiquidation), type(uint256).max);

        TestStateLib.enableReentrancy();

        bool receiveSTokens = true;

        vm.prank(borrower);
        partialLiquidation.liquidationCall(address(token1), address(token0), borrower, debtToRepay, receiveSTokens);
    }

    function verifyReentrancy() external {
        ISiloConfig siloConfig = TestStateLib.siloConfig();
        ISilo silo0 = TestStateLib.silo0();
        ISilo silo1 = TestStateLib.silo1();
        MaliciousToken token0 = MaliciousToken(TestStateLib.token0());
        MaliciousToken token1 = MaliciousToken(TestStateLib.token1());
        address hookReceiver = TestStateLib.hookReceiver();

        bool entered = siloConfig.reentrancyGuardEntered();
        assertTrue(entered, "Reentrancy is not enabled while reentering");

        bool receiveSTokens = true;
        bool isSolvent = silo0.isSolvent(borrower);

        if (isSolvent) {
            // Disable reentrancy to create insolvent borrower.
            vm.prank(hookReceiver);
            siloConfig.turnOffReentrancyProtection();

            _createInsolventBorrower();

            // Enable reentrancy to test liquidation with insolvent borrower.
            // We return to the previous state.
            vm.prank(hookReceiver);
            siloConfig.turnOnReentrancyProtection();

            vm.warp(block.timestamp + 170 days);
        }

        IPartialLiquidation partialLiquidation = IPartialLiquidation(hookReceiver);

        uint256 collateralToLiquidate;
        uint256 debtToRepay;

        (collateralToLiquidate, debtToRepay) = partialLiquidation.maxLiquidation(borrower);

        vm.prank(borrower);
        vm.expectRevert(ICrossReentrancyGuard.CrossReentrantCall.selector);
        partialLiquidation.liquidationCall(address(token1), address(token0), borrower, debtToRepay, receiveSTokens);
    }

    function methodDescription() external pure returns (string memory description) {
        description = "liquidationCall(address,address,address,uint256,bool)";
    }

    function _createInsolventBorrower() internal {
        MaliciousToken token0 = MaliciousToken(TestStateLib.token0());
        MaliciousToken token1 = MaliciousToken(TestStateLib.token1());
        ISilo silo0 = TestStateLib.silo0();
        ISilo silo1 = TestStateLib.silo1();
        uint256 depositAmount = 100e18;
        uint256 collateralAmount = depositAmount * 10;

        // disable reentrancy check in the test so we will not check it on deposit/borrow
        TestStateLib.disableReentrancy();

        token0.mint(depositor, depositAmount);

        vm.prank(depositor);
        token0.approve(address(silo0), depositAmount);

        vm.prank(depositor);
        silo0.deposit(depositAmount, depositor);

        token1.mint(borrower, collateralAmount);

        vm.prank(borrower);
        token1.approve(address(silo1), collateralAmount);

        vm.prank(borrower);
        silo1.deposit(collateralAmount, borrower);

        uint256 maxBorrow = silo0.maxBorrow(borrower);

        emit log_named_uint("maxBorrow", maxBorrow);
        emit log_named_uint("balance borrower", token0.balanceOf(borrower));
        emit log_named_uint("balance silo", token0.balanceOf(address(silo0)));

        vm.prank(borrower);
        silo0.borrow(maxBorrow, borrower, borrower);
    }
}
