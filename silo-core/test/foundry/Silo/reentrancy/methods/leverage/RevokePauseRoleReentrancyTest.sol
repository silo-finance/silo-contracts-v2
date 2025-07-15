// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Ownable} from "openzeppelin5/access/Ownable.sol";

import {LeverageRouter} from "silo-core/contracts/leverage/LeverageRouter.sol";
import {ICrossReentrancyGuard} from "silo-core/contracts/interfaces/ICrossReentrancyGuard.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract RevokePauseRoleReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        _expectRevert();
    }

    function verifyReentrancy() external {
        _expectRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "revokePauseRole(address)";
    }

    function _getLeverageRouter() internal view returns (LeverageRouter) {
        return LeverageRouter(TestStateLib.leverageRouter());
    }

    function _expectRevert() internal {
        LeverageRouter router = _getLeverageRouter();

        vm.expectRevert(abi.encodeWithSelector(
            Ownable.OwnableUnauthorizedAccount.selector,
            address(this)
        ));

        router.revokePauseRole(address(this));
    }
}
