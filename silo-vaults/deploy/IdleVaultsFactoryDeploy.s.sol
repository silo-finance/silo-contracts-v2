// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SiloVaultsContracts} from "silo-vaults/common/SiloVaultsContracts.sol";

import {IdleVaultsFactory} from "silo-vaults/contracts/IdleVaultsFactory.sol";

import {CommonDeploy} from "./common/CommonDeploy.sol";

/*
    FOUNDRY_PROFILE=vaults \
        forge script silo-vaults/deploy/IdleVaultsFactoryDeploy.s.sol:IdleVaultsFactoryDeploy \
        --ffi --rpc-url $RPC_INK --broadcast --verify

    Resume verification:
    FOUNDRY_PROFILE=vaults \
        forge script silo-vaults/deploy/IdleVaultsFactoryDeploy.s.sol:IdleVaultsFactoryDeploy \
        --ffi --rpc-url $RPC_INK \
        --verify \
        --verifier blockscout --verifier-url $VERIFIER_URL_INK \
        --private-key $PRIVATE_KEY \
        --resume
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
