// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IAccessControl} from "openzeppelin5/access/IAccessControl.sol";

import {LeverageRouter} from "silo-core/contracts/leverage/LeverageRouter.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract SetLeverageFeeReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        _expectRevert();
    }

    function verifyReentrancy() external {
        _expectRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "setLeverageFee(uint256)";
    }

    function _getLeverageRouter() internal view returns (LeverageRouter) {
        return LeverageRouter(TestStateLib.leverageRouter());
    }

    function _expectRevert() internal {
        address anyAccount = makeAddr("anyAccount");

        LeverageRouter router = _getLeverageRouter();
        bytes32 adminRole = router.DEFAULT_ADMIN_ROLE();

        vm.expectRevert(abi.encodeWithSelector(
            IAccessControl.AccessControlUnauthorizedAccount.selector,
            anyAccount,
            adminRole
        ));

        vm.prank(anyAccount);
        router.setLeverageFee(0.01e18);
    }
}
