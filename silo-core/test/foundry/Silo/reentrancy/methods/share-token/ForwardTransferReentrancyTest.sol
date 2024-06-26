// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ShareToken} from "silo-core/contracts/utils/ShareToken.sol";
import {ShareTokenMethodReentrancyTest} from "./_ShareTokenMethodReentrancyTest.sol";

contract ForwardTransferReentrancyTest is ShareTokenMethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure will revert as expected (all share tokens)");
        _executeForAllShareTokens(_ensureItWillNotRevert);
    }

    function verifyReentrancy() external {
        _executeForAllShareTokens(_ensureItWillNotRevert);
    }

    function methodDescription() external pure returns (string memory description) {
        description = "forwardTransfer(address,address,uint256)";
    }

    function _ensureItWillNotRevert(address _token) internal {
        vm.expectRevert(IShareToken.OnlySilo.selector);
        ShareToken(_token).forwardTransfer(address(this), address(this), 100);
    }
}
