// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IMethodReentrancyTest} from "../interfaces/IMethodReentrancyTest.sol";
import {TestStateLib} from "../TestState.sol";
import {MaliciousToken} from "../MaliciousToken.sol";

contract BorrowReentrancyTest is Test, IMethodReentrancyTest {
    function callMethod() external {
        MaliciousToken token0 = MaliciousToken(TestStateLib.token0());
        MaliciousToken token1 = MaliciousToken(TestStateLib.token1());
        ISilo silo0 = TestStateLib.silo0();
        ISilo silo1 = TestStateLib.silo1();
        address depositor = makeAddr("Depositor");
        address borrower = makeAddr("Borrower");
        uint256 depositAmount = 100e18;
        uint256 collateralAmount = 100e18;
        uint256 borrowAmount = 50e18;

        token0.mint(depositor, depositAmount);
        token1.mint(borrower, collateralAmount);

        vm.prank(depositor);
        token0.approve(address(silo0), depositAmount);

        vm.prank(depositor);
        silo0.deposit(depositAmount, depositor);

        vm.prank(borrower);
        token1.approve(address(silo1), collateralAmount);

        vm.prank(borrower);
        silo1.deposit(collateralAmount, borrower);

        TestStateLib.enableReentrancy();

        vm.prank(borrower);
        silo0.borrow(borrowAmount, borrower, borrower, false /* same asset */);
    }

    function verifyReentrancy() external {
        ISilo silo0 = TestStateLib.silo0();

        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        silo0.borrow(1000, address(0), address(0), false);

        ISilo silo1 = TestStateLib.silo1();

        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        silo1.borrow(1000, address(0), address(0), false);
    }

    function methodDescription() external pure returns (string memory description) {
        description = "borrow(uint256,address,address,bool)";
    }

    function methodSignature() external pure returns (bytes4 sig) {
        sig = ISilo.borrow.selector;
    }
}
