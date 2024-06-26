// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract AccrueInterestAndGetConfigReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will revert (permissions test)");
        ISiloConfig config = TestStateLib.siloConfig();
        address silo0 = address(TestStateLib.silo0());

        vm.expectRevert(ISiloConfig.OnlySiloOrDebtShareToken.selector);
        config.accrueInterestAndGetConfig(silo0, 0);
    }

    function verifyReentrancy() external {
        ISiloConfig config = TestStateLib.siloConfig();

        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector); // TODO: update error after permissions bug fix
        config.accrueInterestAndGetConfig(address(0), 0);
    }

    function methodDescription() external pure returns (string memory description) {
        description = "accrueInterestAndGetConfig(address,uint256)";
    }
}
