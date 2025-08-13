// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {DynamicKinkModel, IDynamicKinkModel} from "../../../../contracts/interestRateModel/kink/DynamicKinkModel.sol";
import {KinkCommon} from "./KinkCommon.sol";

contract KinkVerifyConfigTest is KinkCommon {
    function setUp() public {
        irm = new DynamicKinkModel();
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_verifyConfig -vv
    */
    function test_kink_verifyConfig() public {
        IDynamicKinkModel.Config memory config;

        config.ulow = 20;
        vm.expectRevert(IDynamicKinkModel.InvalidUlow.selector);
        irm.verifyConfig(config);

        config.u1 = 30e18;
        vm.expectRevert(IDynamicKinkModel.InvalidU1.selector);
        irm.verifyConfig(config);

        config.u1 = 100; // valid
        config.u2 = 40e18;
        vm.expectRevert(IDynamicKinkModel.InvalidU2.selector);
        irm.verifyConfig(config);

        config.u2 = 90;
        vm.expectRevert(IDynamicKinkModel.InvalidU2.selector);
        irm.verifyConfig(config);

        config.u2 = 200; // valid
        vm.expectRevert(IDynamicKinkModel.InvalidUcrit.selector);
        irm.verifyConfig(config);

        // config.ucrit = 100; // valid
        // irm.verifyConfig(config);

        // config.rmin = 100; // valid
        // irm.verifyConfig(config);
    }
}