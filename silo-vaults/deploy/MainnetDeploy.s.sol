// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SiloVaultsFactoryDeploy} from "./SiloVaultsFactoryDeploy.s.sol";
import {PublicAllocatorDeploy} from "./PublicAllocatorDeploy.s.sol";
import {SiloIncentivesControllerCLFactoryDeploy} from "./SiloIncentivesControllerCLFactoryDeploy.s.sol";

/**
    FOUNDRY_PROFILE=vaults \
        forge script silo-vaults/deploy/MainnetDeploy.s.sol:MainnetDeploy \
        --ffi --rpc-url $RPC_SONIC --verify --broadcast
 */
contract MainnetDeploy {
    function run() public {
        SiloVaultsFactoryDeploy siloVaultsFactoryDeploy = new SiloVaultsFactoryDeploy();
        PublicAllocatorDeploy publicAllocatorDeploy = new PublicAllocatorDeploy();

        SiloIncentivesControllerCLFactoryDeploy siloIncentivesControllerCLFactoryDeploy =
            new SiloIncentivesControllerCLFactoryDeploy();

        siloVaultsFactoryDeploy.run();
        publicAllocatorDeploy.run();
        siloIncentivesControllerCLFactoryDeploy.run();
    }
}
