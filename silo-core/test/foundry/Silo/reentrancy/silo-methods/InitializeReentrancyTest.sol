// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IMethodReentrancyTest} from "../interfaces/IMethodReentrancyTest.sol";
import {TestStateLib} from "../TestState.sol";

contract InitializeReentrancyTest is Test, IMethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will revert");
        _ensureItWillRevert();
    }

    function verifyReentrancy() external {
        _ensureItWillRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "initialize(address,address)";
    }

    function methodSignature() external pure returns (bytes4 sig) {
        sig = ISilo.initialize.selector;
    }

    function _ensureItWillRevert() internal {
        ISiloConfig config = ISiloConfig(address(0));
        address modelConfig = address(0);

        ISilo silo0 = TestStateLib.silo0();
        ISilo silo1 = TestStateLib.silo1();

        vm.expectRevert(ISilo.SiloInitialized.selector);
        silo0.initialize(config, modelConfig);

        vm.expectRevert(ISilo.SiloInitialized.selector);
        silo1.initialize(config, modelConfig);
    }
}
