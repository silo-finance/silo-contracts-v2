// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {IInterestRateModelV2} from "silo-core/contracts/interfaces/IInterestRateModelV2.sol";
import {InterestRateModelV2Config} from "silo-core/contracts/interestRateModel/InterestRateModelV2Config.sol";

import {InterestRateModelConfigs} from "../_common/InterestRateModelConfigs.sol";
import {InterestRateModelV2ConfigHarness} from "../_mocks/InterestRateModelV2ConfigHarness.sol";

// forge test -vv --mc InterestRateModelV2ConfigTest
contract InterestRateModelV2ConfigTest is Test, InterestRateModelConfigs {
    /*
    forge test -vv --mt test_IRMC_getConfig_zeros
    */
    function test_IRMC_getConfig_zeros() public {
        IInterestRateModelV2.Config memory empty;

        InterestRateModelV2Config irmc = new InterestRateModelV2Config(empty);

        assertEq(keccak256(abi.encode(empty)), keccak256(abi.encode(irmc.getConfig())), "cfg should be empty");
    }

    /*
    forge test -vv --mt test_IRMC_getConfig_zeros
    */
    function test_IRMC_getConfig_withData() public {
        IInterestRateModelV2.Config memory defaultCfg = _defaultConfig();

        InterestRateModelV2Config irmc = new InterestRateModelV2Config(defaultCfg);

        assertEq(keccak256(abi.encode(defaultCfg)), keccak256(abi.encode(irmc.getConfig())), "cfg should match");
    }

    /*
    forge test -vv --mt test_IRMC_getters
    */
    function test_IRMC_getters() public {
        IInterestRateModelV2.Config memory defaultCfg = _defaultConfig();

        InterestRateModelV2ConfigHarness irmc = new InterestRateModelV2ConfigHarness(defaultCfg);

        assertEq(irmc.uopt(), defaultCfg.uopt, "uopt mismatch");
        assertEq(irmc.ucrit(), defaultCfg.ucrit, "ucrit mismatch");
        assertEq(irmc.ulow(), defaultCfg.ulow, "ulow mismatch");
        assertEq(irmc.ki(), defaultCfg.ki, "ki mismatch");
        assertEq(irmc.kcrit(), defaultCfg.kcrit, "kcrit mismatch");
        assertEq(irmc.klow(), defaultCfg.klow, "klow mismatch");
        assertEq(irmc.klin(), defaultCfg.klin, "klin mismatch");
        assertEq(irmc.beta(), defaultCfg.beta, "beta mismatch");
        assertEq(irmc.ri(), defaultCfg.ri, "ri mismatch");
        assertEq(irmc.Tcrit(), defaultCfg.Tcrit, "Tcrit mismatch");
    }
}
