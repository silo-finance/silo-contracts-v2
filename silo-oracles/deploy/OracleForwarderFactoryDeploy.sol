// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CommonDeploy} from "./CommonDeploy.sol";
import {OracleForwarderFactory} from "silo-oracles/contracts/forwarder/OracleForwarderFactory.sol";
import {SiloOraclesFactoriesContracts} from "./SiloOraclesFactoriesContracts.sol";

/**
    FOUNDRY_PROFILE=oracles \
        forge script silo-oracles/deploy/OracleForwarderFactoryDeploy.sol \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract OracleForwarderFactoryDeploy is CommonDeploy {
    function run() public returns (address factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        factory = address(new OracleForwarderFactory());

        vm.stopBroadcast();

        _registerDeployment(factory, SiloOraclesFactoriesContracts.ORACLE_FORWARDER_FACTORY);
    }
}
