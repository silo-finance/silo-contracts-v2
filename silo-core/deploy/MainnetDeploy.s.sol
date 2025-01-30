// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CommonDeploy} from "./_CommonDeploy.sol";

import {SiloFactoryDeploy} from "./SiloFactoryDeploy.s.sol";
import {InterestRateModelV2FactoryDeploy} from "./InterestRateModelV2FactoryDeploy.s.sol";
import {InterestRateModelV2Deploy} from "./InterestRateModelV2Deploy.s.sol";
import {SiloHookV1Deploy} from "./SiloHookV1Deploy.s.sol";
import {SiloDeployerDeploy} from "./SiloDeployerDeploy.s.sol";
import {LiquidationHelperDeploy} from "./LiquidationHelperDeploy.s.sol";
import {TowerDeploy} from "./TowerDeploy.s.sol";
import {SiloLensDeploy} from "./SiloLensDeploy.s.sol";

/**
    script to deploy whole silo-core

    Note: for deploying without ve-silo, we need adjustment:

    git apply silo-core/deploy/withoutVeSilo.patch

    this patch was created with `git diff > withoutVeSilo.patch`


    ETHERSCAN_API_KEY=$OPTIMISM_API_KEY FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/MainnetDeploy.s.sol \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545 --verify
 */
contract MainnetDeploy is CommonDeploy {
    function run() public {
        SiloFactoryDeploy siloFactoryDeploy = new SiloFactoryDeploy();
        InterestRateModelV2FactoryDeploy interestRateModelV2ConfigFactoryDeploy =
            new InterestRateModelV2FactoryDeploy();
        InterestRateModelV2Deploy interestRateModelV2Deploy = new InterestRateModelV2Deploy();
        SiloHookV1Deploy siloHookV1Deploy = new SiloHookV1Deploy();
        SiloDeployerDeploy siloDeployerDeploy = new SiloDeployerDeploy();
        LiquidationHelperDeploy liquidationHelperDeploy = new LiquidationHelperDeploy();
        SiloLensDeploy siloLensDeploy = new SiloLensDeploy();
        TowerDeploy towerDeploy = new TowerDeploy();

        siloFactoryDeploy.run();
        interestRateModelV2ConfigFactoryDeploy.run();
        interestRateModelV2Deploy.run();
        siloHookV1Deploy.run();
        siloDeployerDeploy.run();
        liquidationHelperDeploy.run();
        siloLensDeploy.run();
        towerDeploy.run();
    }
}
