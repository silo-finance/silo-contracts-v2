// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IMethodReentrancyTest} from "../../interfaces/IMethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";
import {MaliciousToken} from "../../MaliciousToken.sol";

contract RedeemReentrancyTest is Test, IMethodReentrancyTest {
    function callMethod() external {
        MaliciousToken token = MaliciousToken(TestStateLib.token0());
        ISilo silo = TestStateLib.silo0();
        address depositor = makeAddr("Depositor");
        uint256 amount = 100e18;

        TestStateLib.disableReentrancy();

        token.mint(depositor, amount);

        vm.prank(depositor);
        token.approve(address(silo), amount);

        vm.prank(depositor);
        silo.deposit(amount, depositor, ISilo.CollateralType.Collateral);

        TestStateLib.enableReentrancy();

        vm.prank(depositor);
        silo.redeem(amount, depositor, depositor);
    }

    function verifyReentrancy() external {
        ISilo silo0 = TestStateLib.silo0();

        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        silo0.redeem(1000, address(0), address(0));

        ISilo silo1 = TestStateLib.silo1();

        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        silo1.redeem(1000, address(0), address(0));
    }

    function methodDescription() external pure returns (string memory description) {
        description = "redeem(uint256,address,address)";
    }

    function methodSignature() external pure returns (bytes4 sig) {
        sig = 0xba087652;
    }
}
