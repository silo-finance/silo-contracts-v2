// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SiloVaultsContracts} from "silo-vaults/common/SiloVaultsContracts.sol";

import {SiloVaultsFactory, ISiloVaultsFactory} from "../contracts/SiloVaultsFactory.sol";

import {CommonDeploy} from "./common/CommonDeploy.sol";

/*
    ETHERSCAN_API_KEY=$ETHERSCAN_API_KEY FOUNDRY_PROFILE=vaults \
        forge script silo-vaults/deploy/SiloVaultsFactoryDeploy.s.sol:SiloVaultsFactoryDeploy \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545 \
        --verify

*/
contract SiloVaultsFactoryDeploy is CommonDeploy {
    function run() public returns (SiloVaultsFactory siloVaultsFactory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        siloVaultsFactory = new SiloVaultsFactory();

        vm.stopBroadcast();

        _registerDeployment(address(siloVaultsFactory), SiloVaultsContracts.SILO_VAULTS_FACTORY);
    }
}
