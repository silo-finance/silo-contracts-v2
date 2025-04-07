// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {SiloFactoryVeSiloDeploy} from "silo-core/deploy/silo-factory/SiloFactoryVeSiloDeploy.s.sol";
import {MainnetDeploy} from "./MainnetDeploy.s.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/mainnet-deploy/MainnetVeSiloDeploy.s.sol \
        --ffi --rpc-url http://127.0.0.1:8545 --verify --broadcast
 */
contract MainnetVeSiloDeploy is MainnetDeploy {
    function _deploySiloFactory() internal override {
        SiloFactoryVeSiloDeploy siloFactoryDeploy = new SiloFactoryVeSiloDeploy();
        siloFactoryDeploy.run();
    }
}
