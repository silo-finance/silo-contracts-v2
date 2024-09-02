// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {SiloCoreDeployments, SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";

import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc SiloCoreDeploymentsTest
*/
contract SiloCoreDeploymentsTest is SiloLittleHelper, Test {
    string constant _networkName = "anvil";

    function setUp() public {
        _setUpLocalFixture();
    }

    /*
    forge test -vv --ffi --mt test_get_exists
    */
    function test_get_exists() public {
        address liquidationHook = SiloCoreDeployments.get(SiloCoreContracts.PARTIAL_LIQUIDATION, _networkName);
        assertTrue(liquidationHook != address(0), "expect address to be there");
    }

    function test_get_NotExists() public {
        address liquidationHook = SiloCoreDeployments.get("not.exist", _networkName);
        assertEq(liquidationHook, address(partialLiquidation), "expect to return valid address");
    }
}
