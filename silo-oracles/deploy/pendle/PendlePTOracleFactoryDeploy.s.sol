// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";
import {PendlePTOracleFactory} from "silo-oracles/contracts/pendle/PendlePTOracleFactory.sol";
import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";
import {IPyYtLpOracleLike} from "silo-oracles/contracts/pendle/interfaces/IPyYtLpOracleLike.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {console2} from "forge-std/console2.sol";

/**
FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/pendle/PendlePTOracleFactoryDeploy.s.sol \
    --ffi --rpc-url $RPC_SONIC --broadcast --verify
 */
contract PendlePTOracleFactoryDeploy is CommonDeploy {
    function run() public returns (address factory) {
        address pendleOracle = AddrLib.getAddress(AddrKey.PENDLE_ORACLE);

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);

        factory = address(new PendlePTOracleFactory(IPyYtLpOracleLike(pendleOracle)));

        vm.stopBroadcast();

        _registerDeployment(factory, SiloOraclesFactoriesContracts.PENDLE_PT_ORACLE_FACTORY);
    }
}
