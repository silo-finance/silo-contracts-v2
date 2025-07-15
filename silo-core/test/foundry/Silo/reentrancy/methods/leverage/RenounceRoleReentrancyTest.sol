// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {LeverageRouter} from "silo-core/contracts/leverage/LeverageRouter.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract RenounceRoleReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "renounceRole(bytes32,address)";
    }

    function _ensureItWillNotRevert() internal {
        LeverageRouter router = _getLeverageRouter();
        router.renounceRole(router.PAUSER_ROLE(), address(this));
    }

    function _getLeverageRouter() internal view returns (LeverageRouter) {
        return LeverageRouter(TestStateLib.leverageRouter());
    }
}
