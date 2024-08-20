// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {SiloERC4626} from "silo-core/contracts/utils/SiloERC4626.sol";
import {ShareToken} from "silo-core/contracts/utils/ShareToken.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract NoncesReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert (all share tokens)");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "nonces(address)";
    }

    function _ensureItWillNotRevert() internal view {
        SiloERC4626(address(TestStateLib.silo0())).nonces(address(this));
        SiloERC4626(address(TestStateLib.silo1())).nonces(address(this));
    }
}
