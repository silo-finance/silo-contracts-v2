// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {FirmVaultFactory} from "silo-core/contracts/firm/FirmVaultFactory.sol";

import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

/*
 FOUNDRY_PROFILE=core_test forge test --ffi --mc FirmVaultFactoryTest -vvv 
*/
contract FirmVaultFactoryTest is SiloLittleHelper, Test {
    FirmVaultFactory factory = new FirmVaultFactory();

    function setUp() public {
        _setUpLocalFixture();

        token0.setOnDemand(true);
        token1.setOnDemand(true);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_firmFactory_predictAddress_fuzz -vvv 
    */
    function test_firmFactory_predictAddress_fuzz(bytes32 _salt, address _deployer) public {

        address predicted = factory.predictAddress(_salt, _deployer);
        address actual = address(factory.create(_deployer, silo1, _salt));

        assertEq(predicted, actual, "expect predictAddress and create return the same address");
    }
}
