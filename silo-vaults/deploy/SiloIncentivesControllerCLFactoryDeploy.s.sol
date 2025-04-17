// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SiloVaultsContracts} from "silo-vaults/common/SiloVaultsContracts.sol";

import {
    SiloIncentivesControllerCLFactory
} from "silo-vaults/contracts/incentives/claiming-logics/SiloIncentivesControllerCLFactory.sol";

import {CommonDeploy} from "./common/CommonDeploy.sol";

/*
    ETHERSCAN_API_KEY=$ETHERSCAN_API_KEY FOUNDRY_PROFILE=vaults \
        forge script silo-vaults/deploy/SiloIncentivesControllerCLFactoryDeploy.s.sol \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545 \
        --verify
*/
contract SiloIncentivesControllerCLFactoryDeploy is CommonDeploy {
    function run() public returns (address factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);
        factory = address(new SiloIncentivesControllerCLFactory());
        vm.stopBroadcast();

        _registerDeployment(address(factory), SiloVaultsContracts.SILO_INCENTIVES_CONTROLLER_CL_FACTORY);
    }
}
