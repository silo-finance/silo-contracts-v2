// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ShareToken} from "silo-core/contracts/utils/ShareToken.sol";
import {ShareTokenMethodReentrancyTest} from "./_ShareTokenMethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract ForwardTransferFromNoChecksReentrancyTest is ShareTokenMethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure will revert as expected (all share tokens)");
        _executeForAllShareTokens(_ensureItWillRevertOnlySilo);
    }

    function verifyReentrancy() external {
        _executeForAllShareTokens(_ensureItWillRevertOnlySilo);
    }

    function methodDescription() external pure returns (string memory description) {
        description = "forwardTransferFromNoChecks(address,address,uint256)";
    }

    function _ensureItWillRevertOnlySilo(address _token) internal {
        ISiloConfig config = TestStateLib.siloConfig();

        (,, address debt0) = config.getShareTokens(address(TestStateLib.silo0()));
        (,, address debt1) = config.getShareTokens(address(TestStateLib.silo1()));

        if (_token == debt0 || _token == debt1) vm.expectRevert(IShareToken.Forbidden.selector);
        else vm.expectRevert(IShareToken.OnlySilo.selector);

        ShareToken(_token).forwardTransferFromNoChecks(address(0), address(0), 100);
    }
}
