// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {PendleLPTToSyOracleFactory} from "silo-oracles/contracts/pendle/lp-tokens/PendleLPTToSyOracleFactory.sol";
import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";

/**
FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/pendle/PendleLPTToSyOracleFactoryDeploy.s.sol \
    --ffi --rpc-url $RPC_SONIC --broadcast --verify
 */
contract PendleLPTToSyOracleFactoryDeploy is CommonDeploy {
    function run() public returns (address factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);

        factory = address(new PendleLPTToSyOracleFactory());

        vm.stopBroadcast();

        _registerDeployment(factory, SiloOraclesFactoriesContracts.PENDLE_LPT_TO_SY_ORACLE_FACTORY);
    }
}
