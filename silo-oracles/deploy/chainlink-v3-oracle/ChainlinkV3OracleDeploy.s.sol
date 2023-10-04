// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {IUniswapV3Pool} from "uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesContracts} from "../SiloOraclesContracts.sol";
import {ChainlinkV3OraclesConfigsParser as ConfigParser} from "./ChainlinkV3OraclesConfigsParser.sol";
import {ChainlinkV3Oracle} from "silo-oracles/contracts/chainlinkV3/ChainlinkV3Oracle.sol";
import {IChainlinkV3Oracle} from "silo-oracles/contracts/interfaces/IChainlinkV3Oracle.sol";
import {ChainlinkV3OracleFactory} from "silo-oracles/contracts/chainlinkV3/ChainlinkV3OracleFactory.sol";
import {ChainlinkV3OracleDeployments} from "./ChainlinkV3OracleDeployments.sol";

/**
FOUNDRY_PROFILE=oracles CONFIG=demo-config \
    forge script silo-oracles/deploy/chainlink-v3-oracle/ChainlinkV3OracleDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract ChainlinkV3OracleDeploy is CommonDeploy {
    function run() public returns (ChainlinkV3Oracle oracle) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        string memory configName = vm.envString("CONFIG");

        IChainlinkV3Oracle.ChainlinkV3DeploymentConfig memory config = ConfigParser.getConfig(
            getChainAlias(),
            configName
        );

        address factory = getDeployedAddress(SiloOraclesContracts.CHAINLINK_V3_ORACLE_FACTORY);

        oracle = ChainlinkV3OracleFactory(factory).create(config);

        ChainlinkV3OracleDeployments.save(getChainAlias(), configName, address(oracle));

        vm.stopBroadcast();
    }
}
