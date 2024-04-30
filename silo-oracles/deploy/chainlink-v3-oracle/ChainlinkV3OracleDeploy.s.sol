// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";
import {ChainlinkV3OraclesConfigsParser as ConfigParser} from "./ChainlinkV3OraclesConfigsParser.sol";
import {ChainlinkV3Oracle} from "silo-oracles/contracts/chainlinkV3/ChainlinkV3Oracle.sol";
import {IChainlinkV3Oracle} from "silo-oracles/contracts/interfaces/IChainlinkV3Oracle.sol";
import {ChainlinkV3OracleFactory} from "silo-oracles/contracts/chainlinkV3/ChainlinkV3OracleFactory.sol";
import {OraclesDeployments} from "../OraclesDeployments.sol";

/**
FOUNDRY_PROFILE=oracles CONFIG=CHAINLINK_Demo_config \
    forge script silo-oracles/deploy/chainlink-v3-oracle/ChainlinkV3OracleDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract ChainlinkV3OracleDeploy is CommonDeploy {
    function run() public returns (ChainlinkV3Oracle oracle) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        string memory configName = vm.envString("CONFIG");

        IChainlinkV3Oracle.ChainlinkV3DeploymentConfig memory config = ConfigParser.getConfig(
            getChainAlias(),
            configName
        );

        address factory = getDeployedAddress(SiloOraclesFactoriesContracts.CHAINLINK_V3_ORACLE_FACTORY);

        vm.startBroadcast(deployerPrivateKey);

        oracle = ChainlinkV3OracleFactory(factory).create(config);

        vm.stopBroadcast();

        OraclesDeployments.save(getChainAlias(), configName, address(oracle));
    }
}
