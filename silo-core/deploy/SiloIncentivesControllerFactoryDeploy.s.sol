// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CommonDeploy} from "./_CommonDeploy.sol";
import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";

import {SiloIncentivesControllerFactory} from "silo-core/contracts/incentives/SiloIncentivesControllerFactory.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/SiloIncentivesControllerFactoryDeploy.s.sol \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545 --verify
 */
contract SiloIncentivesControllerFactoryDeploy is CommonDeploy {
    function run() public returns (SiloIncentivesControllerFactory factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        factory = SiloIncentivesControllerFactory(address(new SiloIncentivesControllerFactory()));

        vm.stopBroadcast();

        _registerDeployment(address(factory), SiloCoreContracts.INCENTIVES_CONTROLLER_FACTORY);
    }
}
