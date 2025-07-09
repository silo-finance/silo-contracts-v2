// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";

import {RevenueModule} from "silo-core/contracts/leverage/modules/RevenueModule.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";
import {MaliciousToken} from "../../MaliciousToken.sol";

contract RescueTokensSingleReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        RevenueModule leverage = _getLeverage();
        address token = TestStateLib.token0();

        vm.expectRevert(RevenueModule.NoRevenue.selector);
        leverage.rescueTokens(IERC20(token));
    }

    function verifyReentrancy() external {
        RevenueModule leverage = _getLeverage();
        address token = TestStateLib.token0();

        if (IERC20(token).balanceOf(address(leverage)) != 0) {
            vm.expectRevert(RevenueModule.ReceiverNotSet.selector);
        } else {
            vm.expectRevert(RevenueModule.NoRevenue.selector);
        }

        leverage.rescueTokens(IERC20(token));
    }

    function methodDescription() external pure returns (string memory description) {
        description = "rescueTokens(address)";
    }

    function _getLeverage() internal view returns (RevenueModule) {
        return RevenueModule(TestStateLib.leverage());
    }
}
