// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC4626OracleFactory} from "silo-oracles/contracts/erc4626/ERC4626OracleFactory.sol";
import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";

/**
    FOUNDRY_PROFILE=oracles \
        forge script silo-oracles/deploy/erc4626/ERC4626OracleFactoryDeploy.sol \
        --ffi --rpc-url $RPC_SONIC --broadcast --verify
 */
contract ERC4626OracleFactoryDeploy is CommonDeploy {
    function run() public returns (address factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        factory = address(new ERC4626OracleFactory());

        vm.stopBroadcast();

        _registerDeployment(factory, SiloOraclesFactoriesContracts.ERC4626_ORACLE_FACTORY);
    }
}
