// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ICrossReentrancyGuard} from "silo-core/contracts/interfaces/ICrossReentrancyGuard.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";
import {MaliciousToken} from "../../MaliciousToken.sol";

contract LeverageSameAssetReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        MaliciousToken token0 = MaliciousToken(TestStateLib.token0());
        ISilo silo0 = TestStateLib.silo0();
        address depositor = makeAddr("Depositor");
        address borrower = makeAddr("Borrower");
        uint256 depositAmount = 100e18;
        uint256 collateralAmount = 100e18;
        uint256 borrowAmount = 50e18;

        TestStateLib.disableReentrancy();

        token0.mint(depositor, depositAmount);
        token0.mint(borrower, collateralAmount);

        vm.prank(depositor);
        token0.approve(address(silo0), depositAmount);

        vm.prank(depositor);
        silo0.deposit(depositAmount, depositor);

        vm.prank(borrower);
        token0.approve(address(silo0), collateralAmount);

        TestStateLib.enableReentrancy();

        vm.prank(borrower);

        silo0.leverageSameAsset(
            collateralAmount,
            borrowAmount,
            borrower,
            ISilo.CollateralType.Collateral
        );
    }

    function verifyReentrancy() external {
        ISilo silo0 = TestStateLib.silo0();

        vm.expectRevert(ICrossReentrancyGuard.CrossReentrantCall.selector);
        silo0.leverageSameAsset(1000, 1000, address(0), ISilo.CollateralType.Collateral);

        ISilo silo1 = TestStateLib.silo1();

        vm.expectRevert(ICrossReentrancyGuard.CrossReentrantCall.selector);
        silo1.leverageSameAsset(1000, 1000, address(0), ISilo.CollateralType.Collateral);
    }

    function methodDescription() external pure returns (string memory description) {
        description = "leverageSameAsset(uint256,uint256,address,uint8)";
    }
}
