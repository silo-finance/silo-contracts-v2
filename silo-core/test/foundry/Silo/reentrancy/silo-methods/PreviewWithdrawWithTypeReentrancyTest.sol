// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IMethodReentrancyTest} from "../interfaces/IMethodReentrancyTest.sol";
import {TestStateLib} from "../TestState.sol";

contract PreviewWithdrawWithTypeReentrancyTest is Test, IMethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external view {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "previewWithdraw(address,uint8)";
    }

    function methodSignature() external pure returns (bytes4 sig) {
        sig = 0x267e54a7;
    }

    function _ensureItWillNotRevert() internal view {
        uint256 someAmount = 1000_0000e18;

        TestStateLib.silo0().previewWithdraw(someAmount, ISilo.CollateralType.Collateral);
        TestStateLib.silo1().previewWithdraw(someAmount, ISilo.CollateralType.Collateral);

        TestStateLib.silo0().previewWithdraw(someAmount, ISilo.CollateralType.Protected);
        TestStateLib.silo1().previewWithdraw(someAmount, ISilo.CollateralType.Protected);
    }
}
