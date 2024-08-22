// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IERC20Permit} from "openzeppelin5/token/ERC20/extensions/IERC20Permit.sol";

import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract PermitReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");
        _ensureItWillRevertWithOnlySilo();
    }

    function verifyReentrancy() external {
        _ensureItWillRevertWithOnlySilo();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)";
    }

    function _ensureItWillRevertWithOnlySilo() internal {
//        vm.expectRevert(IShareToken.OnlySilo.selector);
        IERC20Permit(address(TestStateLib.silo0())).permit(address(1),address(1),1,2,3,bytes32(0),bytes32(0));

//        vm.expectRevert(IShareToken.OnlySilo.selector);
        IERC20Permit(address(TestStateLib.silo1())).permit(address(1),address(1),1,2,3,bytes32(0),bytes32(0));
    }
}
