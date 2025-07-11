// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";

import {
    LeverageUsingSiloFlashloanWithGeneralSwap
} from "silo-core/contracts/leverage/LeverageUsingSiloFlashloanWithGeneralSwap.sol";
import {LeverageRouter} from "silo-core/contracts/leverage/LeverageRouter.sol";
import {TestStateLib} from "../../TestState.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";

contract RenounceOwnershipReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will revert");
        _ensureItWillRevert();
    }

    function verifyReentrancy() external {
        _ensureItWillRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "renounceOwnership()";
    }

    function _ensureItWillRevert() internal {
        LeverageRouter router = _getLeverageRouter();

        vm.expectRevert(abi.encodeWithSelector(
            Ownable.OwnableUnauthorizedAccount.selector,
            address(this)
        ));

        router.renounceOwnership();
    }

    function _getLeverageRouter() internal view returns (LeverageRouter) {
        return LeverageRouter(TestStateLib.leverageRouter());
    }
}
