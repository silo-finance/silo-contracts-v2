// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";
import {ReentrancyGuard} from "openzeppelin5/utils/ReentrancyGuard.sol";

import {RevenueModule} from "silo-core/contracts/leverage/modules/RevenueModule.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";
import {MaliciousToken} from "../../MaliciousToken.sol";
import {
    LeverageUsingSiloFlashloanWithGeneralSwap
} from "silo-core/contracts/leverage/LeverageUsingSiloFlashloanWithGeneralSwap.sol";
import {ILeverageRouter} from "silo-core/contracts/interfaces/ILeverageRouter.sol";

contract RescueTokensArrayReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        RevenueModule leverage = _getLeverage();
        address token = TestStateLib.token0();

        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = IERC20(token);

        vm.expectRevert(RevenueModule.NoRevenue.selector);

        leverage.rescueTokens(tokens);
    }

    function verifyReentrancy() external {
        RevenueModule leverage = _getLeverage();
        address token = TestStateLib.token0();

        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = IERC20(token);

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        leverage.rescueTokens(tokens);
    }

    function methodDescription() external pure returns (string memory description) {
        description = "rescueTokens(address[])";
    }

    function _getLeverage() internal returns (RevenueModule) {
        ILeverageRouter leverageRouter = ILeverageRouter(TestStateLib.leverageRouter());
        return LeverageUsingSiloFlashloanWithGeneralSwap(leverageRouter.LEVERAGE_IMPLEMENTATION());
    }
}
