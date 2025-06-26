// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";

import {
    ERC4626OracleHardcodeQuoteFactory
} from "silo-oracles/contracts/erc4626/ERC4626OracleHardcodeQuoteFactory.sol";

/**
    FOUNDRY_PROFILE=oracles \
        forge script silo-oracles/deploy/erc4626/ERC4626OracleHardcodeQuoteFactoryDeploy.sol \
        --ffi --rpc-url $RPC_AVALANCHE --broadcast --verify

    FOUNDRY_PROFILE=oracles \
        forge script silo-oracles/deploy/erc4626/ERC4626OracleHardcodeQuoteFactoryDeploy.sol \
        --ffi --rpc-url $RPC_AVALANCHE \
        --verify \
        --resume \
        --private-key $PRIVATE_KEY
 */
contract ERC4626OracleHardcodeQuoteFactoryDeploy is CommonDeploy {
    function run() public returns (address factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        factory = address(new ERC4626OracleHardcodeQuoteFactory());

        vm.stopBroadcast();

        _registerDeployment(factory, SiloOraclesFactoriesContracts.ERC4626_ORACLE_HARDCODE_QUOTE_FACTORY);
    }
}
