// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {CommonDeploy} from "./_CommonDeploy.sol";

import {SiloFactoryDeploy} from "./SiloFactoryDeploy.s.sol";
import {InterestRateModelV2FactoryDeploy} from "./InterestRateModelV2FactoryDeploy.s.sol";
import {InterestRateModelV2Deploy} from "./InterestRateModelV2Deploy.s.sol";
import {PartialLiquidationDeploy} from "./PartialLiquidationDeploy.s.sol";
import {GaugeHookReceiverDeploy} from "./GaugeHookReceiverDeploy.s.sol";
import {SiloDeployerDeploy} from "./SiloDeployerDeploy.s.sol";
import {SiloLensDeploy} from "./SiloLensDeploy.s.sol";
import {SiloRouterDeploy} from "./SiloRouterDeploy.s.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/MainnetDeploy.s.sol \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract MainnetDeploy is CommonDeploy {
    function run() public {
        SiloFactoryDeploy siloFactoryDeploy = new SiloFactoryDeploy();
        InterestRateModelV2FactoryDeploy interestRateModelV2ConfigFactoryDeploy =
            new InterestRateModelV2FactoryDeploy();
        InterestRateModelV2Deploy interestRateModelV2Deploy = new InterestRateModelV2Deploy();
        PartialLiquidationDeploy siloLiquidationDeploy = new PartialLiquidationDeploy();
        GaugeHookReceiverDeploy gaugeHookReceiverDeploy = new GaugeHookReceiverDeploy();
        SiloDeployerDeploy siloDeployerDeploy = new SiloDeployerDeploy();
        SiloLensDeploy siloLensDeploy = new SiloLensDeploy();
        SiloRouterDeploy siloRouterDeploy = new SiloRouterDeploy();

        siloFactoryDeploy.run();
        interestRateModelV2ConfigFactoryDeploy.run();
        interestRateModelV2Deploy.run();
        siloLiquidationDeploy.run();
        gaugeHookReceiverDeploy.run();
        siloDeployerDeploy.run();
        siloLensDeploy.run();
        siloRouterDeploy.run();
    }
}
