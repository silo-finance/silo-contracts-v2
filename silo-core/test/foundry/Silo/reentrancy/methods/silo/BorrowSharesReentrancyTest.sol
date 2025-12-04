// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {console2} from "forge-std/console2.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ICrossReentrancyGuard} from "silo-core/contracts/interfaces/ICrossReentrancyGuard.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";
import {MaliciousToken} from "../../MaliciousToken.sol";

contract BorrowSharesReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        MaliciousToken token0 = MaliciousToken(TestStateLib.token0());
        MaliciousToken token1 = MaliciousToken(TestStateLib.token1());
        ISilo silo0 = TestStateLib.silo0();
        ISilo silo1 = TestStateLib.silo1();
        address depositor = makeAddr("Depositor");
        address borrower = makeAddr("Borrower");
        // in case silo is not empty and we have huge interest, 
        // depossiting totalAssetsAmount should create liquidity
        uint256 depositAmount = 1e18 + silo1.totalAssets();
        uint256 collateralAmount = 3e18;

        TestStateLib.disableReentrancy();

        token1.mint(depositor, depositAmount);
        token0.mint(borrower, collateralAmount);

        vm.prank(depositor);
        token1.approve(address(silo1), depositAmount);

        vm.prank(depositor);
        silo1.deposit(depositAmount, depositor);

        vm.prank(borrower);
        token0.approve(address(silo0), collateralAmount);

        vm.prank(borrower);
        silo0.deposit(collateralAmount, borrower);

        TestStateLib.enableReentrancy();

        uint256 borrowAmount = silo1.maxBorrowShares(borrower);

        if (borrowAmount == 0) {
            console2.log("[BorrowSharesReentrancyTest] borrow amount is 0");
            revert("[BorrowSharesReentrancyTest] borrow amount is 0");
        }

        vm.prank(borrower);
        silo1.borrowShares(borrowAmount, borrower, borrower);
    }

    function verifyReentrancy() external {
        ISilo silo0 = TestStateLib.silo0();

        vm.expectRevert(ICrossReentrancyGuard.CrossReentrantCall.selector);
        silo0.borrowShares(1000, address(0), address(0));

        ISilo silo1 = TestStateLib.silo1();

        vm.expectRevert(ICrossReentrancyGuard.CrossReentrantCall.selector);
        silo1.borrowShares(1000, address(0), address(0));
    }

    function methodDescription() external pure returns (string memory description) {
        description = "borrowShares(uint256,address,address)";
    }
}
