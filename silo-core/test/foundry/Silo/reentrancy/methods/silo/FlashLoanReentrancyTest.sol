// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {Silo} from "silo-core/contracts/Silo.sol";
import {IMethodReentrancyTest} from "../../interfaces/IMethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract FlashLoanReentrancyTest is Test, IMethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tDo nothing");
    }

    function verifyReentrancy() external view {
    }

    function methodDescription() external pure returns (string memory description) {
        description = "flashLoan(address,address,uint256,bytes)";
    }

    function methodSignature() external pure returns (bytes4 sig) {
        sig = Silo.flashLoan.selector;
    }
}
