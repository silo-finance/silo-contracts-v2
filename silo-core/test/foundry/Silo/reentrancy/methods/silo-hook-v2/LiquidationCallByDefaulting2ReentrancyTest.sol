// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IPartialLiquidationByDefaulting} from "silo-core/contracts/interfaces/IPartialLiquidationByDefaulting.sol";
import {LiquidationCallByDefaultingReentrancyTest} from "./LiquidationCallByDefaultingReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";

contract LiquidationCallByDefaulting2ReentrancyTest is LiquidationCallByDefaultingReentrancyTest {
    function _liquidationCallByDefaulting(address _borrower) internal override {
        IPartialLiquidationByDefaulting partialLiquidation =
            IPartialLiquidationByDefaulting(TestStateLib.hookReceiver());

        vm.prank(_borrower);
        IPartialLiquidationByDefaulting(address(partialLiquidation)).liquidationCallByDefaulting(
            _borrower, type(uint256).max
        );
    }

    function _logPrefix(string memory _msg) internal pure override returns (string memory) {
        return string.concat("[LiquidationCallByDefaulting2ReentrancyTest] ", _msg);
    }

    function methodDescription() external pure override returns (string memory description) {
        description = "liquidationCallByDefaulting(address,uint256)";
    }
}
