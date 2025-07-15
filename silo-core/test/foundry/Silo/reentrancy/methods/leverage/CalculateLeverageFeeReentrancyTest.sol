// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {
    LeverageUsingSiloFlashloanWithGeneralSwap
} from "silo-core/contracts/leverage/LeverageUsingSiloFlashloanWithGeneralSwap.sol";
import {ILeverageRouter} from "silo-core/contracts/interfaces/ILeverageRouter.sol";
import {LeverageRouter} from "silo-core/contracts/leverage/LeverageRouter.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract CalculateLeverageFeeReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert)");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "calculateLeverageFee(uint256)";
    }

    function _ensureItWillNotRevert() internal {
        LeverageUsingSiloFlashloanWithGeneralSwap leverage = _getLeverage();
        leverage.calculateLeverageFee(1000e18);
    }

    function _getLeverage() internal returns (LeverageUsingSiloFlashloanWithGeneralSwap) {
        ILeverageRouter leverageRouter = ILeverageRouter(TestStateLib.leverageRouter());
        return LeverageUsingSiloFlashloanWithGeneralSwap(leverageRouter.LEVERAGE_IMPLEMENTATION());
    }
}
