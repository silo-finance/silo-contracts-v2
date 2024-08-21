// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ShareToken} from "silo-core/contracts/utils/ShareToken.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract DomainSeparatorReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert (all share tokens)");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "DOMAIN_SEPARATOR()";
    }

    function _ensureItWillNotRevert() internal view {
        TestStateLib.silo0().DOMAIN_SEPARATOR();
        TestStateLib.silo1().DOMAIN_SEPARATOR();
    }
}
