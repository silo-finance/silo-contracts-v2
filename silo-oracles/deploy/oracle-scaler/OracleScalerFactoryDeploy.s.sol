// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {OracleScalerFactory} from "silo-oracles/contracts/scaler/OracleScalerFactory.sol";
import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";

/**
FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/oracle-scaler/OracleScalerFactoryDeploy.s.sol \
    --ffi --rpc-url $RPC_SONIC --broadcast --verify
 */
contract OracleScalerFactoryDeploy is CommonDeploy {
    function run() public returns (address factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        factory = address(new OracleScalerFactory());

        vm.stopBroadcast();

        _registerDeployment(factory, SiloOraclesFactoriesContracts.ORACLE_SCALER_FACTORY);
    }
}
