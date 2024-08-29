// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {IInterestRateModelV2} from "silo-core/contracts/interfaces/IInterestRateModelV2.sol";
import {InterestRateModelV2Config} from "silo-core/contracts/interestRateModel/InterestRateModelV2Config.sol";
import {InterestRateModelV2ConfigFactory} from "silo-core/contracts/interestRateModel/InterestRateModelV2ConfigFactory.sol";

import {InterestRateModelConfigs} from "../_common/InterestRateModelConfigs.sol";
import {InterestRateModelV2Impl} from "./InterestRateModelV2Impl.sol";
import {InterestRateModelV2Checked} from "./InterestRateModelV2Checked.sol";

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
}
