// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract AccrueInterestAndGetConfigOptimisedReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will revert (permissions test)");
        ISiloConfig config = TestStateLib.siloConfig();

        vm.expectRevert(ISiloConfig.OnlySiloOrDebtShareToken.selector);
        config.accrueInterestAndGetConfigOptimised(0, ISilo.CollateralType.Collateral);
    }

    function verifyReentrancy() external {
        ISiloConfig config = TestStateLib.siloConfig();

        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector); // TODO: update error after permissions bug fix
        config.accrueInterestAndGetConfigOptimised(0, ISilo.CollateralType.Collateral);
    }

    function methodDescription() external pure returns (string memory description) {
        description = "accrueInterestAndGetConfigOptimised(uint256,uint8)";
    }
}
