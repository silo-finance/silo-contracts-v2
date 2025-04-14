// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

import {ManualLiquidationHelper2TokensTest} from "./ManualLiquidationHelper_2tokens.i.sol";

/*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mc ManualLiquidationHelper2TokensReceiverTest
*/
contract ManualLiquidationHelper2TokensReceiverTest is ManualLiquidationHelper2TokensTest {
    function _executeLiquidation() internal override {
        LIQUIDATION_HELPER.executeLiquidation(silo1, BORROWER, 2 ** 128, false, _tokenReceiver());
    }

    function _tokenReceiver() internal override returns (address payable) {
        return payable(address(this));
    }
}
