// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";

import {SiloLittleHelper} from "../../../_common/SiloLittleHelper.sol";

/*
FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc LiquidationWrongSiloTest
*/
contract LiquidationWrongInputsTest is SiloLittleHelper, Test {
    ISiloConfig internal _siloConfig;

    function setUp() public {
       _siloConfig = _setUpLocalFixture();
    }

    /*
    forge test -vv --ffi --mt test_liquidationInput_NoDebtToCover
    */
    function test_liquidationInput_NoDebtToCover() public {
        vm.expectRevert(IPartialLiquidation.NoDebtToCover.selector);

        partialLiquidation.liquidationCall(
            address(0),
            address(0),
            address(0),
            0,
            false
        );
    }
}
