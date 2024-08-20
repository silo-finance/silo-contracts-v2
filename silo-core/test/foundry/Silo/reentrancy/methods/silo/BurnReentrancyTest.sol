// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ICrossReentrancyGuard} from "silo-core/contracts/interfaces/ICrossReentrancyGuard.sol";
import {SiloERC4626} from "silo-core/contracts/utils/SiloERC4626.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ShareToken} from "silo-core/contracts/utils/ShareToken.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract BurnReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will revert as expected (both silos)");
        _ensureItWillRevertOnlySilo();
    }

    function verifyReentrancy() external {
         ISiloConfig config = TestStateLib.siloConfig();

        bool entered = config.reentrancyGuardEntered();
        assertTrue(entered, "Reentrancy is not enabled on a burn");

        _ensureItWillRevertOnlySilo();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "burn(address,address,uint256)";
    }

    function _ensureItWillRevertOnlySilo() internal {
        vm.expectRevert(IShareToken.OnlySilo.selector);
        SiloERC4626(address(TestStateLib.silo0())).burn(address(0), address(0), 0);

        vm.expectRevert(IShareToken.OnlySilo.selector);
        SiloERC4626(address(TestStateLib.silo1())).burn(address(0), address(0), 0);
    }
}
