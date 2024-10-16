// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";

import {SiloLittleHelper} from "../../../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc PartialLiquidationTest
*/
contract PartialLiquidationTest is SiloLittleHelper, Test {
    function setUp() public {
        _setUpLocalFixture();
    }

    function test_partialLiquidation_beforeAction() public {
        // can be called
        IHookReceiver(address(partialLiquidation)).beforeAction(address(0), 0, "");
    }

    function test_partialLiquidation_afterAction() public {
        // can be called
        IHookReceiver(address(partialLiquidation)).afterAction(address(0), 0, "");
    }
}
