// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {SiloVaultsContracts} from "silo-vaults/common/SiloVaultsContracts.sol";

import {IdleVaultsFactory} from "silo-vaults/contracts/IdleVaultsFactory.sol";

import {CommonDeploy} from "./common/CommonDeploy.sol";

/*
    ETHERSCAN_API_KEY=$ETHERSCAN_API_KEY FOUNDRY_PROFILE=vaults \
        forge script silo-vaults/deploy/IdleVaultsFactoryDeploy.s.sol:IdleVaultsFactoryDeploy \
        --ffi --rpc-url $RPC_SONIC \
        --broadcast --verify
*/
contract IdleVaultsFactoryDeploy is CommonDeploy {
    function run() public returns (IdleVaultsFactory factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);
        factory = new IdleVaultsFactory();
        vm.stopBroadcast();

        _registerDeployment(address(factory), SiloVaultsContracts.IDLE_VAULTS_FACTORY);
    }
}
