// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {SiloERC4626} from "silo-core/contracts/utils/SiloERC4626.sol";
import {TestStateLib} from "../../TestState.sol";

contract AllowanceReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "allowance(address,address)";
    }

    function _ensureItWillNotRevert() internal {
        SiloERC4626 silo0 = SiloERC4626(address(TestStateLib.silo0()));
        SiloERC4626 silo1 = SiloERC4626(address(TestStateLib.silo1()));

        address anyAddr1 = makeAddr("Any address 1");
        address anyAddr2 = makeAddr("Any address 2");

        silo0.allowance(anyAddr1, anyAddr2);
        silo1.allowance(anyAddr1, anyAddr2);
    }
}
