// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract ForwardTransferFromNoChecksTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will revert with OnlySilo");
        _ensureItWillRevertWithOnlySilo();
    }

    function verifyReentrancy() external {
        _ensureItWillRevertWithOnlySilo();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "forwardTransferFromNoChecks(address,address,uint256)";
    }

    function _ensureItWillRevertWithOnlySilo() internal {
        vm.expectRevert(IShareToken.OnlySilo.selector);
        IShareToken(address(TestStateLib.silo0())).forwardTransferFromNoChecks(address(1), address(2), 3);

        vm.expectRevert(IShareToken.OnlySilo.selector);
        IShareToken(address(TestStateLib.silo1())).forwardTransferFromNoChecks(address(1), address(2), 3);
    }
}
