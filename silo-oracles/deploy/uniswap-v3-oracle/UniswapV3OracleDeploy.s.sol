// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

import {IUniswapV3Pool} from "uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";
import {UniswapV3OraclesConfigsParser as ConfigParser} from "./UniswapV3OraclesConfigsParser.sol";
import {OraclesDeployments} from "../OraclesDeployments.sol";
import {UniswapV3Oracle} from "silo-oracles/contracts/uniswapV3/UniswapV3Oracle.sol";
import {UniswapV3OracleFactory} from "silo-oracles/contracts/uniswapV3/UniswapV3OracleFactory.sol";
import {IUniswapV3Oracle} from "silo-oracles/contracts/interfaces/IUniswapV3Oracle.sol";

/**
FOUNDRY_PROFILE=oracles CONFIG=UniV3-ETH-USDC-0.3 \
    forge script silo-oracles/deploy/uniswap-v3-oracle/UniswapV3OracleDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract UniswapV3OracleDeploy is CommonDeploy {
    function run() public returns (UniswapV3Oracle oracle) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        string memory configName = vm.envString("CONFIG");

        IUniswapV3Oracle.UniswapV3DeploymentConfig memory config = ConfigParser.getConfig(
            getChainAlias(),
            configName
        );

        address factory = getDeployedAddress(SiloOraclesFactoriesContracts.UNISWAP_V3_ORACLE_FACTORY);

        vm.startBroadcast(deployerPrivateKey);

        oracle = UniswapV3OracleFactory(factory).create(config);

        vm.stopBroadcast();

        OraclesDeployments.save(getChainAlias(), configName, address(oracle));
    }
}
