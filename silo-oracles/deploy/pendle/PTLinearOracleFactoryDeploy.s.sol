// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {PTLinearOracleFactory} from "../../../contracts/pendle/linear/PTLinearOracleFactory.sol";
import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";

/**
FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/pendle/PTLinearOracleFactoryDeploy.s.sol \
    --ffi --rpc-url $RPC_AVALANCHE --broadcast --verify
 */
contract PTLinearOracleFactoryDeploy is CommonDeploy {
    function run() public returns (address factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);

        factory = address(new PTLinearOracleFactory());

        vm.stopBroadcast();

        _registerDeployment(factory, SiloOraclesFactoriesContracts.PT_LINEAR_ORACLE_FACTORY);
    }
}
