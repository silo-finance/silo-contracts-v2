// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {ReentrancyGuard} from "openzeppelin5/utils/ReentrancyGuard.sol";
import {Vm} from "forge-std/Vm.sol";

import {RescueModule} from "silo-core/contracts/leverage/modules/RescueModule.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";
import {ILeverageRouter} from "silo-core/contracts/interfaces/ILeverageRouter.sol";

contract RescueNativeTokensReentrancyTest is MethodReentrancyTest {
    // The same as user that opened leverage position
    Vm.Wallet public wallet = vm.createWallet("User");

    function callMethod() external {
        ILeverageRouter leverageRouter = ILeverageRouter(TestStateLib.leverageRouter());
        RescueModule leverage = RescueModule(leverageRouter.LEVERAGE_IMPLEMENTATION());

        vm.expectRevert(RescueModule.OnlyLeverageUser.selector);
        leverage.rescueNativeTokens();
    }

    function verifyReentrancy() external {
        ILeverageRouter leverageRouter = ILeverageRouter(TestStateLib.leverageRouter());
        RescueModule module = RescueModule(leverageRouter.predictUserLeverageContract(wallet.addr));

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        module.rescueNativeTokens();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "rescueNativeTokens()";
    }
}
