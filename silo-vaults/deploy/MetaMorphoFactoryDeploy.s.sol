// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SiloVaultsContracts} from "silo-vaults/common/SiloVaultsContracts.sol";

import {MetaSiloFactory} from "../contracts/MetaSiloFactory.sol";

import {CommonDeploy} from "./common/CommonDeploy.sol";

/*
    ETHERSCAN_API_KEY=$ETHERSCAN_API_KEY FOUNDRY_PROFILE=vaults \
        forge script silo-vaults/deploy/MetaSiloFactoryDeploy.s.sol:MetaSiloFactoryDeploy \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545 \
        --verify

    MetaSilo verification:

    cast abi-encode "constructor(address,uint256,address,string,string)" \
    0xB85420016C1Df4e6Ad6e461Cf927913B5E04A430 86400 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1 "Test Vault1" "TV1"

    ETHERSCAN_API_KEY=$ARBISCAN_API_KEY FOUNDRY_PROFILE=vaults forge verify-contract \
    0xdA72ab48AD4389B427b44d0dad393D5E5b209514 silo-vaults/contracts/MetaSilo.sol:MetaSilo \
    --chain 42161 --watch --compiler-version v0.8.28+commit.7893614a \
    --constructor-args <cast abi-encode output>

*/
contract MetaSiloFactoryDeploy is CommonDeploy {
    function run() public returns (MetaSiloFactory MetaSiloFactory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        MetaSiloFactory = new MetaSiloFactory();

        vm.stopBroadcast();

        _registerDeployment(address(MetaSiloFactory), SiloVaultsContracts.META_SILO_FACTORY);
    }
}
