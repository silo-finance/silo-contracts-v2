// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract FakeSilo {
    function accrueInterestForConfig(address,uint256,uint256) external {}
}

contract AccrueInterestAndGetConfigReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will revert (permissions test)");
        ISiloConfig config = TestStateLib.siloConfig();

        vm.expectRevert(); // failed to accrued interest for the msg.sender
        config.accrueInterestAndGetConfig(makeAddr("Any address"), 0);

        // trying with malicous silo
        FakeSilo fakeSilo = new FakeSilo();

         vm.expectRevert(ISiloConfig.WrongSilo.selector);
         config.accrueInterestAndGetConfig(address(fakeSilo), 0);
    }

    function verifyReentrancy() external {
        ISiloConfig config = TestStateLib.siloConfig();

        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        config.accrueInterestAndGetConfig(address(0), 0);
    }

    function methodDescription() external pure returns (string memory description) {
        description = "accrueInterestAndGetConfig(address,uint256)";
    }
}
