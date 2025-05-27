// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AddrKey} from "common/addresses/AddrKey.sol";
import {PendleLPTOracleFactory} from "silo-oracles/contracts/pendle/PendleLPTOracleFactory.sol";
import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {console2} from "forge-std/console2.sol";

/**
FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/pendle/PendleLPTOracleFactoryDeploy.s.sol \
    --ffi --rpc-url $RPC_SONIC --broadcast --verify
 */
contract PendleLPTOracleFactoryDeploy is CommonDeploy {
    function run() public returns (address factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);

        factory = address(new PendleLPTOracleFactory());

        vm.stopBroadcast();

        _registerDeployment(factory, SiloOraclesFactoriesContracts.PENDLE_LPT_ORACLE_FACTORY);
    }
}
