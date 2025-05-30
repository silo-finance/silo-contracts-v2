// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {PendleLPTToAssetOracleFactory} from "silo-oracles/contracts/pendle/lp-tokens/PendleLPTToAssetOracleFactory.sol";
import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";

/**
FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/pendle/PendleLPTToAssetOracleFactoryDeploy.s.sol \
    --ffi --rpc-url $RPC_SONIC --broadcast --verify
 */
contract PendleLPTToAssetOracleFactoryDeploy is CommonDeploy {
    function run() public returns (address factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);

        factory = address(new PendleLPTToAssetOracleFactory());

        vm.stopBroadcast();

        _registerDeployment(factory, SiloOraclesFactoriesContracts.PENDLE_LPT_TO_ASSET_ORACLE_FACTORY);
    }
}
