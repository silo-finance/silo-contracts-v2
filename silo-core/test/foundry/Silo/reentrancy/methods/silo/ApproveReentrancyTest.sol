// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {SiloERC4626} from "silo-core/contracts/utils/SiloERC4626.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract ApproveReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "approve(address,uint256)";
    }

    function _ensureItWillNotRevert() internal {
        SiloERC4626 silo0 = SiloERC4626(address(TestStateLib.silo0()));
        SiloERC4626 silo1 = SiloERC4626(address(TestStateLib.silo1()));

        address anyAddr = makeAddr("Any address");

        silo0.approve(anyAddr, 1e18);
        silo1.approve(anyAddr, 1e18);
    }
}
