// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IMethodReentrancyTest} from "../interfaces/IMethodReentrancyTest.sol";
import {TestStateLib} from "../TestState.sol";
import {MaliciousToken} from "../MaliciousToken.sol";

contract TransitionCollateralReentrancyTest is Test, IMethodReentrancyTest {
    function callMethod() external {
        MaliciousToken token0 = MaliciousToken(TestStateLib.token0());
        ISilo silo0 = TestStateLib.silo0();
        address depositor = makeAddr("Depositor");
        uint256 depositAmount = 100e18;

        TestStateLib.disableReentrancy();

        token0.mint(depositor, depositAmount);

        vm.prank(depositor);
        token0.approve(address(silo0), depositAmount);

        vm.prank(depositor);
        silo0.deposit(depositAmount, depositor);

        TestStateLib.enableReentrancy();

        vm.prank(depositor);
        silo0.transitionCollateral(depositAmount / 2, depositor, ISilo.CollateralType.Collateral);
    }

    function verifyReentrancy() external {
        ISilo silo0 = TestStateLib.silo0();

        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        silo0.transitionCollateral(1000, address(0), ISilo.CollateralType.Protected);

        ISilo silo1 = TestStateLib.silo1();

        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        silo1.transitionCollateral(1000, address(0), ISilo.CollateralType.Protected);
    }

    function methodDescription() external pure returns (string memory description) {
        description = "transitionCollateral(uint256,address,uint8)";
    }

    function methodSignature() external pure returns (bytes4 sig) {
        sig = ISilo.transitionCollateral.selector;
    }
}
