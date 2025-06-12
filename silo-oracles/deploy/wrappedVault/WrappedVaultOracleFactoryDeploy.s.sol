// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IUniswapV3Factory} from  "uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";
import {WrappedVaultOracleFactory} from "silo-oracles/contracts/wrappedVault/WrappedVaultOracleFactory.sol";

/**
FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/wrappedVault/WrappedVaultOracleFactoryDeploy.s.sol \
    --ffi --rpc-url $RPC_MAINNET --broadcast --verify

//Resume verification:
//FOUNDRY_PROFILE=oracles \
//    forge script silo-oracles/deploy/wrappedVault/WrappedVaultOracleFactoryDeploy.s.sol \
//    --ffi --rpc-url $RPC_MAINNET \
//    --verify \
//    --verifier blockscout \
//    --verifier-url $VERIFIER_URL_INK \
//    --private-key $PRIVATE_KEY \
//    --resume
//
//FOUNDRY_PROFILE=oracles forge verify-contract <contract-address> \
//    WrappedVaultOracleFactory \
//    --compiler-version 0.8.28 \
//    --rpc-url $RPC_MAINNET \
//    --watch
 */
contract WrappedVaultOracleFactoryDeploy is CommonDeploy {
    function run() public returns (WrappedVaultOracleFactory factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);

        factory = new WrappedVaultOracleFactory();
        
        vm.stopBroadcast();

        _registerDeployment(address(factory), SiloOraclesFactoriesContracts.WRAPPED_VAULT_ORACLE_FACTORY);
    }
}
