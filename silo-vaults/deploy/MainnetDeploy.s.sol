// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SiloVaultsFactoryDeploy} from "./SiloVaultsFactoryDeploy.s.sol";
import {PublicAllocatorDeploy} from "./PublicAllocatorDeploy.s.sol";
import {IdleVaultsFactoryDeploy} from "./IdleVaultsFactoryDeploy.s.sol";
import {SiloIncentivesControllerCLFactoryDeploy} from "./SiloIncentivesControllerCLFactoryDeploy.s.sol";
import {SiloVaultsDeployerDeploy} from "./SiloVaultsDeployerDeploy.s.sol";
import {SiloIncentivesControllerCLDeployerDeploy} from "./SiloIncentivesControllerCLDeployerDeploy.s.sol";

/**
    FOUNDRY_PROFILE=vaults \
        forge script silo-vaults/deploy/MainnetDeploy.s.sol:MainnetDeploy \
        --ffi --rpc-url $RPC_SONIC --verify --broadcast

    XDC chain deployment:

    FOUNDRY_PROFILE=vaults \
        forge script silo-vaults/deploy/MainnetDeploy.s.sol:MainnetDeploy \
        --ffi --rpc-url $RPC_XDC --legacy --broadcast --verify

    FOUNDRY_PROFILE=vaults \
        forge script silo-vaults/deploy/MainnetDeploy.s.sol:MainnetDeploy \
        --verifier-url $VERIFIER_URL_ETHERSCAN_V2 \
        --verifier etherscan \
        --chain 50 \
        --ffi --rpc-url $RPC_XDC \
        --etherscan-api-key $ETHERSCAN_API_KEY \
        --verify \
        --private-key $PRIVATE_KEY \
        --legacy \
        --resume
 */
contract MainnetDeploy {
    function run() public {
        SiloVaultsFactoryDeploy siloVaultsFactoryDeploy = new SiloVaultsFactoryDeploy();
        PublicAllocatorDeploy publicAllocatorDeploy = new PublicAllocatorDeploy();
        IdleVaultsFactoryDeploy idleVaultsFactoryDeploy = new IdleVaultsFactoryDeploy();
        SiloVaultsDeployerDeploy siloVaultsDeployerDeploy = new SiloVaultsDeployerDeploy();
        SiloIncentivesControllerCLDeployerDeploy siloIncentivesControllerCLDeployerDeploy =
            new SiloIncentivesControllerCLDeployerDeploy();

        SiloIncentivesControllerCLFactoryDeploy siloIncentivesControllerCLFactoryDeploy =
            new SiloIncentivesControllerCLFactoryDeploy();

        siloVaultsFactoryDeploy.run();
        publicAllocatorDeploy.run();
        idleVaultsFactoryDeploy.run();
        siloIncentivesControllerCLFactoryDeploy.run();
        siloVaultsDeployerDeploy.run();
        siloIncentivesControllerCLDeployerDeploy.run();
    }
}
