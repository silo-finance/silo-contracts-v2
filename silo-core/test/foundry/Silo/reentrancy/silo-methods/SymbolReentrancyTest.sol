// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {SiloERC4626} from "silo-core/contracts/utils/SiloERC4626.sol";
import {IMethodReentrancyTest} from "../interfaces/IMethodReentrancyTest.sol";
import {TestStateLib} from "../TestState.sol";

contract SymbolReentrancyTest is Test, IMethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external view {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "symbol()";
    }

    function methodSignature() external pure returns (bytes4 sig) {
        sig = SiloERC4626.symbol.selector;
    }

    function _ensureItWillNotRevert() internal view {
        SiloERC4626(address(TestStateLib.silo0())).symbol();
        SiloERC4626(address(TestStateLib.silo1())).symbol();
    }
}
