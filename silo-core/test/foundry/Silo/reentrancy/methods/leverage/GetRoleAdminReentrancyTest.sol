// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {LeverageRouter} from "silo-core/contracts/leverage/LeverageRouter.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract GetRoleAdminReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "getRoleAdmin(bytes32)";
    }

    function _ensureItWillNotRevert() internal {
        LeverageRouter router = _getLeverageRouter();
        router.getRoleAdmin(router.PAUSER_ROLE());
    }

    function _getLeverageRouter() internal view returns (LeverageRouter) {
        return LeverageRouter(TestStateLib.leverageRouter());
    }
}
