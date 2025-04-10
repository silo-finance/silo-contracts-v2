// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SiloVaultsContracts} from "silo-vaults/common/SiloVaultsContracts.sol";

import {SiloVaultsDeployer} from "../contracts/SiloVaultsDeployer.sol";

import {ISiloVaultsFactory} from "../contracts/interfaces/ISiloVaultsFactory.sol";
import {IdleVaultsFactory} from "../contracts/IdleVaultsFactory.sol";

import {CommonDeploy} from "./common/CommonDeploy.sol";

/*
    ETHERSCAN_API_KEY=$ETHERSCAN_API_KEY FOUNDRY_PROFILE=vaults \
        forge script silo-vaults/deploy/SiloVaultsDeployerDeploy.s.sol:SiloVaultsDeployerDeploy \
        --ffi --rpc-url http://127.0.0.1:8545 \
        --broadcast --verify
*/
contract SiloVaultsDeployerDeploy is CommonDeploy {
    function run() public returns (SiloVaultsDeployer vaultsDeployer) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address vaultsFactory = getDeployedAddress(SiloVaultsContracts.SILO_VAULTS_FACTORY);
        address idleVaultsFactory = getDeployedAddress(SiloVaultsContracts.IDLE_VAULTS_FACTORY);

        vm.startBroadcast(deployerPrivateKey);

        vaultsDeployer = new SiloVaultsDeployer(
            ISiloVaultsFactory(vaultsFactory),
            IdleVaultsFactory(idleVaultsFactory)
        );

        vm.stopBroadcast();

        _registerDeployment(address(vaultsDeployer), SiloVaultsContracts.SILO_VAULTS_DEPLOYER);
    }
}
