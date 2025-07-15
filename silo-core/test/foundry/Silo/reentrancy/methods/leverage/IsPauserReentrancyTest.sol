// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {LeverageRouter} from "silo-core/contracts/leverage/LeverageRouter.sol";
import {ICrossReentrancyGuard} from "silo-core/contracts/interfaces/ICrossReentrancyGuard.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract IsPauserReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        _callMethod();
    }

    function verifyReentrancy() external {
        _callMethod();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "isPauser(address)";
    }

    function _getLeverageRouter() internal view returns (LeverageRouter) {
        return LeverageRouter(TestStateLib.leverageRouter());
    }

    function _callMethod() internal {
        LeverageRouter router = _getLeverageRouter();
        router.isPauser(address(this));
    }
}
