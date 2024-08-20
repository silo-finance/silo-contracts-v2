// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ICrossReentrancyGuard} from "silo-core/contracts/interfaces/ICrossReentrancyGuard.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ShareToken} from "silo-core/contracts/utils/ShareToken.sol";
import {SiloERC4626} from "silo-core/contracts/utils/SiloERC4626.sol";
import {TestStateLib} from "../../TestState.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";

contract ForwardTransferFromNoChecksReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure will revert as expected (both silos)");
        _ensureItWillRevertOnlySilo();
    }

    function verifyReentrancy() external {
        _ensureItWillRevertOnlySilo();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "forwardTransferFromNoChecks(address,address,uint256)";
    }

    function _ensureItWillRevertOnlySilo() internal {
        address silo0 = address(TestStateLib.silo0());
        vm.expectRevert(IShareToken.OnlySilo.selector);
        SiloERC4626(silo0).forwardTransferFromNoChecks(address(0), address(0), 100);

        address silo1 = address(TestStateLib.silo1());
        vm.expectRevert(IShareToken.OnlySilo.selector);
        SiloERC4626(silo1).forwardTransferFromNoChecks(address(0), address(0), 100);
    }
}
