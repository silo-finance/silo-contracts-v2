// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {IInterestRateModelV2} from "silo-core/contracts/interfaces/IInterestRateModelV2.sol";
import {IInterestRateModelV2Config} from "silo-core/contracts/interfaces/IInterestRateModelV2Config.sol";
import {InterestRateModelV2} from "silo-core/contracts/interestRateModel/InterestRateModelV2.sol";
import {InterestRateModelV2ConfigFactory} from "silo-core/contracts/interestRateModel/InterestRateModelV2ConfigFactory.sol";

import {InterestRateModelConfigs} from "../_common/InterestRateModelConfigs.sol";
import {InterestRateModelV2Impl} from "./InterestRateModelV2Impl.sol";
import {InterestRateModelV2Checked} from "./InterestRateModelV2Checked.sol";

// forge test -vv --mc InterestRateModelV2ConfigFactoryTest
contract InterestRateModelV2ConfigFactoryTest is Test, InterestRateModelConfigs {
    InterestRateModelV2ConfigFactory factory;

    function setUp() public {
        factory = new InterestRateModelV2ConfigFactory();
    }

    /*
    forge test -vv --mt test_IRMF_hashConfig
    */
    function test_IRMF_hashConfig() public view {
        IInterestRateModelV2.Config memory config;
        assertEq(keccak256(abi.encode(config)), factory.hashConfig(config), "hash should match");
    }

    /*
    forge test -vv --mt test_IRMF_verifyConfig
    */
    function test_IRMF_verifyConfig() public {
        IInterestRateModelV2.Config memory config;

        vm.expectRevert(IInterestRateModelV2.InvalidUopt.selector);
        factory.verifyConfig(config);

        config.uopt = -1;
        vm.expectRevert(IInterestRateModelV2.InvalidUopt.selector);
        factory.verifyConfig(config);

        config.uopt = int256(factory.DP());
        vm.expectRevert(IInterestRateModelV2.InvalidUopt.selector);
        factory.verifyConfig(config);

        config.uopt = 0.5e18; // valid

        config.ucrit = config.uopt - 1;
        vm.expectRevert(IInterestRateModelV2.InvalidUcrit.selector);
        factory.verifyConfig(config);

        config.ucrit = int256(factory.DP());
        vm.expectRevert(IInterestRateModelV2.InvalidUcrit.selector);
        factory.verifyConfig(config);

        config.ucrit = config.uopt + 1; // valid

        config.ulow = -1;
        vm.expectRevert(IInterestRateModelV2.InvalidUlow.selector);
        factory.verifyConfig(config);

        config.ulow = config.uopt + 1;
        vm.expectRevert(IInterestRateModelV2.InvalidUlow.selector);
        factory.verifyConfig(config);

        config.ulow = config.uopt - 1; // valid

        config.ki = -1;
        vm.expectRevert(IInterestRateModelV2.InvalidKi.selector);
        factory.verifyConfig(config);

        config.ki = 1; // valid

        config.kcrit = -1;
        vm.expectRevert(IInterestRateModelV2.InvalidKcrit.selector);
        factory.verifyConfig(config);

        config.kcrit = 1; // valid

        config.klow = -1;
        vm.expectRevert(IInterestRateModelV2.InvalidKlow.selector);
        factory.verifyConfig(config);

        config.klow = 1; // valid

        config.klin = -1;
        vm.expectRevert(IInterestRateModelV2.InvalidKlin.selector);
        factory.verifyConfig(config);

        config.klin = 1; // valid

        config.beta = -1;
        vm.expectRevert(IInterestRateModelV2.InvalidBeta.selector);
        factory.verifyConfig(config);

        config.beta = 1;
        factory.verifyConfig(config);

        factory.verifyConfig(_defaultConfig());
    }

    /*
    forge test -vv --mt test_IRMF_create_new
    */
    function test_IRMF_create_new() public {
        IInterestRateModelV2.Config memory config = _defaultConfig();

        (bytes32 id, IInterestRateModelV2Config configContract) = factory.create(config);

        assertEq(id, factory.hashConfig(config), "id is hash");
        assertEq(address(configContract), address(factory.getConfigAddress(id)), "config address is stored");
    }

    /*
    forge test -vv --mt test_IRMF_create_reusable
    */
    function test_IRMF_create_reusable() public {
        IInterestRateModelV2.Config memory config = _defaultConfig();

        (bytes32 id, IInterestRateModelV2Config configContract) = factory.create(config);
        (bytes32 id2, IInterestRateModelV2Config configContract2) = factory.create(config);

        assertEq(id, id2, "id is the same for same config");
        assertEq(address(configContract), address(configContract2), "config address is the same");
    }
}