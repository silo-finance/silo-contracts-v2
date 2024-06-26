// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract PreviewDepositWithTypeReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external view {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "previewDeposit(address,uint8)";
    }

    function _ensureItWillNotRevert() internal view {
        uint256 someAmount = 1000_0000e18;

        TestStateLib.silo0().previewDeposit(someAmount, ISilo.CollateralType.Collateral);
        TestStateLib.silo1().previewDeposit(someAmount, ISilo.CollateralType.Collateral);

        TestStateLib.silo0().previewDeposit(someAmount, ISilo.CollateralType.Protected);
        TestStateLib.silo1().previewDeposit(someAmount, ISilo.CollateralType.Protected);
    }
}
