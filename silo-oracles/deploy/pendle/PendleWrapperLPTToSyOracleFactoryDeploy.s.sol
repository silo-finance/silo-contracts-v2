// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";

import {
    PendleWrapperLPTToSyOracleFactory
} from "silo-oracles/contracts/pendle/lp-tokens/wrappers/PendleWrapperLPTToSyOracleFactory.sol";

/**
FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/pendle/PendleWrapperLPTToSyOracleFactoryDeploy.s.sol \
    --ffi --rpc-url $RPC_SONIC --broadcast --verify
 */
contract PendleWrapperLPTToSyOracleFactoryDeploy is CommonDeploy {
    function run() public returns (address factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);

        factory = address(new PendleWrapperLPTToSyOracleFactory());

        vm.stopBroadcast();

        _registerDeployment(factory, SiloOraclesFactoriesContracts.PENDLE_WRAPPER_LPT_TO_SY_ORACLE_FACTORY);
    }
}
