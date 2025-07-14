// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";
import {ReentrancyGuard} from "openzeppelin5/utils/ReentrancyGuard.sol";
import {Vm} from "forge-std/Vm.sol";

import {RevenueModule} from "silo-core/contracts/leverage/modules/RevenueModule.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";
import {MaliciousToken} from "../../MaliciousToken.sol";
import {
    LeverageUsingSiloFlashloanWithGeneralSwap
} from "silo-core/contracts/leverage/LeverageUsingSiloFlashloanWithGeneralSwap.sol";
import {ILeverageRouter} from "silo-core/contracts/interfaces/ILeverageRouter.sol";

contract RescueTokensSingleReentrancyTest is MethodReentrancyTest {
    // The same as user that opened leverage position
    Vm.Wallet public wallet = vm.createWallet("User");

    function callMethod() external {
        ILeverageRouter leverageRouter = ILeverageRouter(TestStateLib.leverageRouter());
        RevenueModule leverage = RevenueModule(leverageRouter.LEVERAGE_IMPLEMENTATION());
        address token = TestStateLib.token0();

        vm.expectRevert(RevenueModule.NoRevenue.selector);
        leverage.rescueTokens(IERC20(token));
    }

    function verifyReentrancy() external {
        ILeverageRouter leverageRouter = ILeverageRouter(TestStateLib.leverageRouter());
        RevenueModule module = RevenueModule(leverageRouter.predictUserLeverageContract(wallet.addr));

        address token = TestStateLib.token0();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        module.rescueTokens(IERC20(token));
    }

    function methodDescription() external pure returns (string memory description) {
        description = "rescueTokens(address)";
    }
}
