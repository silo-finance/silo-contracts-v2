// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {
    LeverageUsingSiloFlashloanWithGeneralSwap
} from "silo-core/contracts/leverage/LeverageUsingSiloFlashloanWithGeneralSwap.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract NativeTokenReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert)");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "NATIVE_TOKEN()";
    }

    function _ensureItWillNotRevert() internal {
        LeverageUsingSiloFlashloanWithGeneralSwap leverage = _getLeverage();
        leverage.NATIVE_TOKEN();
    }

    function _getLeverage() internal view returns (LeverageUsingSiloFlashloanWithGeneralSwap) {
        return LeverageUsingSiloFlashloanWithGeneralSwap(TestStateLib.leverage());
    }
}
