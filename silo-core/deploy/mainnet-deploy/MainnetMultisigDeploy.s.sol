// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {SiloFactoryMultisigDeploy} from "silo-core/deploy/silo-factory/SiloFactoryMultisigDeploy.s.sol";
import {MainnetDeploy} from "./MainnetDeploy.s.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/mainnet-deploy/MainnetMultisigDeploy.s.sol \
        --ffi --rpc-url http://127.0.0.1:8545 --verify --broadcast
 */
contract MainnetMultisigDeploy is MainnetDeploy {
    function _deploySiloFactory() internal override {
        SiloFactoryMultisigDeploy siloFactoryDeploy = new SiloFactoryMultisigDeploy();
        siloFactoryDeploy.run();
    }
}
