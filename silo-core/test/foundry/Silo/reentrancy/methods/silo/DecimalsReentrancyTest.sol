// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {SiloERC4626} from "silo-core/contracts/utils/SiloERC4626.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract DecimalsReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external view {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "decimals()";
    }

    function _ensureItWillNotRevert() internal view {
        SiloERC4626(address(TestStateLib.silo0())).config();
        SiloERC4626(address(TestStateLib.silo1())).config();
    }
}
