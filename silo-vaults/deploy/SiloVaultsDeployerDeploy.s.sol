// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SiloVaultsContracts} from "silo-vaults/common/SiloVaultsContracts.sol";

import {SiloVaultsDeployer} from "../contracts/SiloVaultsDeployer.sol";

import {ISiloVaultsFactory} from "./interfaces/ISiloVaultsFactory.sol";
import {IdleVaultsFactory} from "./IdleVaultsFactory.sol";

import {CommonDeploy} from "./common/CommonDeploy.sol";

/*
    ETHERSCAN_API_KEY=$ETHERSCAN_API_KEY FOUNDRY_PROFILE=vaults \
        forge script silo-vaults/deploy/SiloVaultsDeployerDeploy.s.sol:SiloVaultsDeployerDeploy \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545 \
        --verify
*/
contract SiloVaultsDeployerDeploy is CommonDeploy {
    function run() public returns (SiloVaultsDeployer vaultsDeployer) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        ISiloVaultsFactory vaultsFactory = getDeployedAddress(SiloCoreContracts.SILO_VAULTS_FACTORY);
        ISiloVaultsFactory idleVaultsFactory = getDeployedAddress(SiloCoreContracts.IDLE_VAULTS_FACTORY);

        vm.startBroadcast(deployerPrivateKey);

        vaultsDeployer = new SiloVaultsDeployer(vaultsFactory, idleVaultsFactory);

        vm.stopBroadcast();

        _registerDeployment(address(vaultsDeployer), SiloVaultsContracts.SILO_VAULTS_DEPLOYER);
    }
}
