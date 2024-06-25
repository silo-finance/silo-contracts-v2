// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {IERC3156FlashLender} from "silo-core/contracts/interfaces/IERC3156FlashLender.sol";
import {IMethodReentrancyTest} from "../interfaces/IMethodReentrancyTest.sol";
import {TestStateLib} from "../TestState.sol";

contract MaxFlashLoanReentrancyTest is Test, IMethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external view {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "maxFlashLoan(address)";
    }

    function methodSignature() external pure returns (bytes4 sig) {
        sig = IERC3156FlashLender.maxFlashLoan.selector;
    }

    function _ensureItWillNotRevert() view internal {
        address token0 = TestStateLib.token0();
        address token1 = TestStateLib.token1();

        IERC3156FlashLender(address(TestStateLib.silo0())).maxFlashLoan(token0);
        IERC3156FlashLender(address(TestStateLib.silo1())).maxFlashLoan(token0);

        IERC3156FlashLender(address(TestStateLib.silo0())).maxFlashLoan(token1);
        IERC3156FlashLender(address(TestStateLib.silo1())).maxFlashLoan(token1);
    }
}
