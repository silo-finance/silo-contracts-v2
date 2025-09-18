// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IDynamicKinkModel} from "../../../../contracts/interfaces/IDynamicKinkModel.sol";
import {DynamicKinkModelConfig} from "../../../../contracts/interestRateModel/kink/DynamicKinkModelConfig.sol";

import {KinkCommonTest} from "./KinkCommon.t.sol";

contract DynamicKinkModelConfigTest is KinkCommonTest {
    DynamicKinkModelConfig config;

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_config_getConfig -vv
    */
    function test_kink_config_getConfig(
        IDynamicKinkModel.Config memory _config,
        IDynamicKinkModel.ImmutableConfig memory _immutableConfig
    ) public {
        config = new DynamicKinkModelConfig(_config, _immutableConfig);
        (IDynamicKinkModel.Config memory cfg, IDynamicKinkModel.ImmutableConfig memory immutableCfg) =
            config.getConfig();

        bytes32 configHashIn = _hashConfig(_config);
        bytes32 immutableConfigHashIn = _hashImmutableConfig(_immutableConfig);

        bytes32 configHashOut = _hashConfig(cfg);
        bytes32 immutableConfigHashOut = _hashImmutableConfig(immutableCfg);

        assertEq(configHashIn, configHashOut, "configHashIn != configHashOut");
        assertEq(immutableConfigHashIn, immutableConfigHashOut, "immutableConfigHashIn != immutableConfigHashOut");
    }
}
