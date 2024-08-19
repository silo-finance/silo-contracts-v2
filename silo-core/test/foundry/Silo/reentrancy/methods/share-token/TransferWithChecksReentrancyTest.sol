// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ShareToken} from "silo-core/contracts/utils/ShareToken.sol";
import {ShareTokenMethodReentrancyTest} from "./_ShareTokenMethodReentrancyTest.sol";

contract TransferWithChecksReentrancyTest is ShareTokenMethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert (all share tokens)");
        _executeForAllShareTokens(_ensureItWillNotRevert);
    }

    function verifyReentrancy() external {
        _executeForAllShareTokens(_ensureItWillNotRevert);
    }

    function methodDescription() external pure returns (string memory description) {
        description = "transferWithChecks()";
    }

    function _ensureItWillNotRevert(address _token) internal view {
        // ShareToken(_token).transferWithChecks(); // TODO do we need this to be public?
    }
}
