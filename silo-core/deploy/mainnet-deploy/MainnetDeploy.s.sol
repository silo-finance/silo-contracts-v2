// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CommonDeploy} from "../_CommonDeploy.sol";

import {InterestRateModelV2FactoryDeploy} from "../InterestRateModelV2FactoryDeploy.s.sol";
import {InterestRateModelV2Deploy} from "../InterestRateModelV2Deploy.s.sol";
import {SiloHookV1Deploy} from "../SiloHookV1Deploy.s.sol";
import {SiloDeployerDeploy} from "../SiloDeployerDeploy.s.sol";
import {LiquidationHelperDeploy} from "../LiquidationHelperDeploy.s.sol";
import {TowerDeploy} from "../TowerDeploy.s.sol";
import {SiloLensDeploy} from "../SiloLensDeploy.s.sol";
import {SiloRouterDeploy} from "../SiloRouterDeploy.s.sol";
import {SiloIncentivesControllerGaugeLikeFactoryDeploy} from "../SiloIncentivesControllerGaugeLikeFactoryDeploy.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/MainnetDeploy.s.sol \
        --ffi --rpc-url http://127.0.0.1:8545 --verify --broadcast
 */
abstract contract MainnetDeploy is CommonDeploy {
    function run() public {
        InterestRateModelV2FactoryDeploy interestRateModelV2ConfigFactoryDeploy =
            new InterestRateModelV2FactoryDeploy();
        InterestRateModelV2Deploy interestRateModelV2Deploy = new InterestRateModelV2Deploy();
        SiloHookV1Deploy siloHookV1Deploy = new SiloHookV1Deploy();
        SiloDeployerDeploy siloDeployerDeploy = new SiloDeployerDeploy();
        LiquidationHelperDeploy liquidationHelperDeploy = new LiquidationHelperDeploy();
        SiloLensDeploy siloLensDeploy = new SiloLensDeploy();
        TowerDeploy towerDeploy = new TowerDeploy();
        SiloRouterDeploy siloRouterDeploy = new SiloRouterDeploy();

        SiloIncentivesControllerGaugeLikeFactoryDeploy siloIncentivesControllerGaugeLikeFactoryDeploy =
            new SiloIncentivesControllerGaugeLikeFactoryDeploy();

        _deploySiloFactory();
        interestRateModelV2ConfigFactoryDeploy.run();
        interestRateModelV2Deploy.run();
        siloHookV1Deploy.run();
        siloDeployerDeploy.run();
        liquidationHelperDeploy.run();
        siloLensDeploy.run();
        towerDeploy.run();
        siloRouterDeploy.run();
        siloIncentivesControllerGaugeLikeFactoryDeploy.run();
    }

    function _deploySiloFactory() internal virtual {}
}
