// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ShareDebtToken} from "silo-core/contracts/utils/ShareDebtToken.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract DecreaseReceiveAllowanceReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will not revert)");
        _ensureItWillNotRevert();
    }

    function verifyReentrancy() external {
        _ensureItWillNotRevert();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "decreaseReceiveAllowance(address,uint256)";
    }

    function _ensureItWillNotRevert() internal {
        ISiloConfig config = TestStateLib.siloConfig();
        ISilo silo0 = TestStateLib.silo0();
        ISilo silo1 = TestStateLib.silo1();

        address borrower = makeAddr("Borrower");
        address receiver = makeAddr("Receiver");

        (,,address debtToken) = config.getShareTokens(address(silo0));

        uint256 allowance = 1000_0000e18;

        vm.prank(receiver);
        ShareDebtToken(debtToken).setReceiveApproval(borrower, allowance);

        vm.prank(receiver);
        ShareDebtToken(debtToken).decreaseReceiveAllowance(borrower, allowance);

        (,, debtToken) = config.getShareTokens(address(silo1));

        vm.prank(receiver);
        ShareDebtToken(debtToken).setReceiveApproval(borrower, allowance);

        vm.prank(receiver);
        ShareDebtToken(debtToken).decreaseReceiveAllowance(borrower, allowance);
    }
}
