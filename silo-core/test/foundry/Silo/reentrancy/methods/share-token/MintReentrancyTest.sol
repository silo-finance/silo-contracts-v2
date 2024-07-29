// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ICrossReentrancyGuard} from "silo-core/contracts/interfaces/ICrossReentrancyGuard.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ShareToken} from "silo-core/contracts/utils/ShareToken.sol";
import {ShareTokenMethodReentrancyTest} from "./_ShareTokenMethodReentrancyTest.sol";

contract MintReentrancyTest is ShareTokenMethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will revert as expected (all share tokens)");
        _executeForAllShareTokens(_ensureItWillRevertOnlySilo);
    }

    function verifyReentrancy() external {
        _executeForAllShareTokens(_ensureItWillRevertOnlySilo);
    }

    function methodDescription() external pure returns (string memory description) {
        description = "mint(address,address,uint256)";
    }

    function _ensureItWillRevertOnlySilo(address _token) internal {
        vm.expectRevert(IShareToken.OnlySilo.selector);
        ShareToken(_token).mint(address(this), address(this), 1000e18);
    }
}
