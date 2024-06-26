// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";

contract FlashLoanReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tDo nothing");
    }

    function verifyReentrancy() external view {
    }

    function methodDescription() external pure returns (string memory description) {
        description = "flashLoan(address,address,uint256,bytes)";
    }
}
