// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract MintTokenReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will revert");
        _ensureItWillRevertWithOnlySilo();
    }

    function verifyReentrancy() external {
        _ensureItWillRevertWithOnlySilo();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "mint(address,address,uint256)";
    }

    function _ensureItWillRevertWithOnlySilo() internal {
        vm.expectRevert(IShareToken.OnlySilo.selector);
        IShareToken(address(TestStateLib.silo0())).mint(address(1), address(2), 3);

        vm.expectRevert(IShareToken.OnlySilo.selector);
        IShareToken(address(TestStateLib.silo1())).mint(address(1), address(2), 3);
    }
}
