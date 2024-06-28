// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract FakeSilo {
    function accrueInterestForConfig(address,uint256,uint256) external {}
}

contract AccrueInterestAndGetConfigOptimisedReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will revert (permissions test)");
        ISiloConfig config = TestStateLib.siloConfig();

        vm.expectRevert(); // failed to accrued interest for the msg.sender
        config.accrueInterestAndGetConfigOptimised(0, ISilo.CollateralType.Collateral);

        // trying with mailicous silo
        FakeSilo fakeSilo = new FakeSilo();

         vm.expectRevert(ISiloConfig.WrongSilo.selector);
         vm.prank(address(fakeSilo));
         config.accrueInterestAndGetConfigOptimised(0, ISilo.CollateralType.Collateral);
    }

    function verifyReentrancy() external {
        ISiloConfig config = TestStateLib.siloConfig();

        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        config.accrueInterestAndGetConfigOptimised(0, ISilo.CollateralType.Collateral);
    }

    function methodDescription() external pure returns (string memory description) {
        description = "accrueInterestAndGetConfigOptimised(uint256,uint8)";
    }
}
