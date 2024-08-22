// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {Initializable} from "openzeppelin5/proxy/utils/Initializable.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract InitializeTokenReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will revert for token initialisation method");
        _ensureItWillRevertWithInvalidInitialization();
    }

    function verifyReentrancy() external {
        _ensureItWillRevertWithInvalidInitialization();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "initialize(address,address,uint24)";
    }

    function _ensureItWillRevertWithInvalidInitialization() internal {
        address silo0 = address(TestStateLib.silo0());
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        IShareToken(silo0).initialize(ISilo(silo0), address(2), 3);

        address silo1 = address(TestStateLib.silo1());
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        IShareToken(silo1).initialize(ISilo(silo1), address(2), 3);
    }
}
