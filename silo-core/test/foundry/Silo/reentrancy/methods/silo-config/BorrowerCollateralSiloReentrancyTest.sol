// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract BorrowerCollateralSiloReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "borrowerCollateralSilo(address)";
    }

    function _ensureItWillNotRevert() internal {
        ISiloConfig config = TestStateLib.siloConfig();
        address borrower = makeAddr("Borrower");

        config.borrowerCollateralSilo(borrower);
        config.borrowerCollateralSilo(address(0));
    }
}
