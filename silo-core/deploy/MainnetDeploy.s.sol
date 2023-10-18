// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {CommonDeploy} from "./_CommonDeploy.sol";

import {SiloFactoryDeploy} from "./SiloFactoryDeploy.s.sol";
import {InterestRateModelV2ConfigFactoryDeploy} from "./InterestRateModelV2ConfigFactoryDeploy.s.sol";
import {InterestRateModelV2Deploy} from "./InterestRateModelV2Deploy.s.sol";
import {HookReceiverDeploy} from "./HookReceiverDeploy.s.sol";
import {HookReceiversFactoryDeploy} from "./HookReceiversFactoryDeploy.s.sol";

/**
    FOUNDRY_PROFILE=silo-core \
        forge script silo-core/deploy/MainnetDeploy.s.sol \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract MainnetDeploy is CommonDeploy {
    function run() public {
        SiloFactoryDeploy siloFactoryDeploy = new SiloFactoryDeploy();
        InterestRateModelV2ConfigFactoryDeploy interestRateModelV2ConfigFactoryDeploy =
            new InterestRateModelV2ConfigFactoryDeploy();
        InterestRateModelV2Deploy interestRateModelV2Deploy = new InterestRateModelV2Deploy();
        HookReceiverDeploy hookReceiverDeploy = new HookReceiverDeploy();
        HookReceiversFactoryDeploy hookReceiversFactoryDeploy = new HookReceiversFactoryDeploy();

        siloFactoryDeploy.run();
        interestRateModelV2ConfigFactoryDeploy.run();
        interestRateModelV2Deploy.run();
        hookReceiverDeploy.run();
        hookReceiversFactoryDeploy.run();
    }
}
