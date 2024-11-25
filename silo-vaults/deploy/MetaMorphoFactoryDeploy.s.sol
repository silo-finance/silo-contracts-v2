// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SiloVaultsContracts} from "silo-vaults/common/SiloVaultsContracts.sol";

import {MetaMorphoFactory} from "../contracts/MetaMorphoFactory.sol";

import {CommonDeploy} from "./common/CommonDeploy.sol";

/*
    ETHERSCAN_API_KEY=$ETHERSCAN_API_KEY FOUNDRY_PROFILE=vaults \
        forge script silo-vaults/deploy/MetaMorphoFactoryDeploy.s.sol:MetaMorphoFactoryDeploy \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545 \
        --verify
*/
contract MetaMorphoFactoryDeploy is CommonDeploy {
    function run() public returns (MetaMorphoFactory metaMorphoFactory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        metaMorphoFactory = new MetaMorphoFactory();

        vm.stopBroadcast();

        _registerDeployment(address(metaMorphoFactory), SiloVaultsContracts.META_MORPHO_FACTORY);
    }
}
