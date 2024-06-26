// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ShareToken} from "silo-core/contracts/utils/ShareToken.sol";
import {ShareTokenMethodReentrancyTest} from "./_ShareTokenMethodReentrancyTest.sol";

contract BurnReentrancyTest is ShareTokenMethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will revert as expected (all share tokens)");
        _executeForAllShareTokens(_ensureItWillRevert);
    }

    function verifyReentrancy() external {
        _executeForAllShareTokens(_ensureItWillRevert);
    }

    function methodDescription() external pure returns (string memory description) {
        description = "burn(address,address,uint256)";
    }

    function _ensureItWillRevert(address _token) internal {
        vm.expectRevert(IShareToken.OnlySilo.selector);
        ShareToken(_token).burn(address(0), address(0), 0);
    }
}
