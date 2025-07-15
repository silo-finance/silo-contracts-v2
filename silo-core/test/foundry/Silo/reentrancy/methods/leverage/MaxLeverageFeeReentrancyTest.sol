// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {
    LeverageRouterRevenueModule
} from "silo-core/contracts/leverage/modules/LeverageRouterRevenueModule.sol";
import {ILeverageRouter} from "silo-core/contracts/interfaces/ILeverageRouter.sol";
import {LeverageRouter} from "silo-core/contracts/leverage/LeverageRouter.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract MaxLeverageFeeReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert)");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external view {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "MAX_LEVERAGE_FEE()";
    }

    function _ensureItWillNotRevert() internal view {
        LeverageRouterRevenueModule leverage = _getLeverage();
        leverage.MAX_LEVERAGE_FEE();
    }

    function _getLeverage() internal view returns (LeverageRouterRevenueModule) {
        return LeverageRouterRevenueModule(TestStateLib.leverageRouter());
    }
}
