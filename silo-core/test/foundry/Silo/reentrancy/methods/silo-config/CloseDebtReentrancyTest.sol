// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract CloseDebtReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will revert (permissions test)");
        ISiloConfig config = TestStateLib.siloConfig();

        vm.expectRevert(ISiloConfig.OnlySiloOrDebtShareToken.selector);
        config.closeDebt(address(0));
    }

    function verifyReentrancy() external {
        ISiloConfig config = TestStateLib.siloConfig();

        vm.expectRevert(ISiloConfig.OnlySiloOrDebtShareToken.selector);
        config.closeDebt(address(0));
    }

    function methodDescription() external pure returns (string memory description) {
        description = "closeDebt(address)";
    }
}
