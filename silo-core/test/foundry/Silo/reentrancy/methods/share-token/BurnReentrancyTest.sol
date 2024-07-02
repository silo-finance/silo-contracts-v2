// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ShareToken} from "silo-core/contracts/utils/ShareToken.sol";
import {ShareTokenMethodReentrancyTest} from "./_ShareTokenMethodReentrancyTest.sol";

contract BurnReentrancyTest is ShareTokenMethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will revert as expected (all share tokens)");
        _executeForAllShareTokens(_ensureItWillRevertOnlySilo);
    }

    function verifyReentrancy() external {
        _executeForAllShareTokensForSilo(_ensureItWillRevertReentrancy);
    }

    function methodDescription() external pure returns (string memory description) {
        description = "burn(address,address,uint256)";
    }

    function _ensureItWillRevertOnlySilo(address _token) internal {
        vm.expectRevert(IShareToken.OnlySilo.selector);
        ShareToken(_token).burn(address(0), address(0), 0);
    }

    function _ensureItWillRevertReentrancy(address _silo, address _token) internal {
        vm.prank(_silo);
        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        ShareToken(_token).burn(address(0), address(0), 0);
    }
}
