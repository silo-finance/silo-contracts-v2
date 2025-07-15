// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {PausableWithRole} from "common/utils/PausableWithRole.sol";

import {LeverageRouter} from "silo-core/contracts/leverage/LeverageRouter.sol";
import {ICrossReentrancyGuard} from "silo-core/contracts/interfaces/ICrossReentrancyGuard.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract PauseReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        _expectRevert();
    }

    function verifyReentrancy() external {
        _expectRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "pause()";
    }

    function _getLeverageRouter() internal view returns (LeverageRouter) {
        return LeverageRouter(TestStateLib.leverageRouter());
    }

    function _expectRevert() internal {
        LeverageRouter router = _getLeverageRouter();

        vm.expectRevert(abi.encodeWithSelector(
            PausableWithRole.OnlyPauseRole.selector
        ));

        router.pause();
    }
}
