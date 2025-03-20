// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";
import {PendlePTToAssetOracleFactory} from "silo-oracles/contracts/pendle/PendlePTToAssetOracleFactory.sol";
import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";
import {IPyYtLpOracleLike} from "silo-oracles/contracts/pendle/interfaces/IPyYtLpOracleLike.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

/**
FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/pendle/PendlePTToAssetOracleFactoryDeploy.s.sol \
    --ffi --rpc-url $RPC_SONIC --broadcast --verify
 */
contract PendlePTToAssetOracleFactoryDeploy is CommonDeploy {
    function run() public returns (address factory) {
        address pendleOracle = AddrLib.getAddress(AddrKey.PENDLE_ORACLE);

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);

        factory = address(new PendlePTToAssetOracleFactory(IPyYtLpOracleLike(pendleOracle)));

        vm.stopBroadcast();

        _registerDeployment(factory, SiloOraclesFactoriesContracts.PENDLE_PT_TO_ASSET_ORACLE_FACTORY);
    }
}
