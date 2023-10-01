// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

import {SiloAddresses, SiloAddrKey} from "common/SiloAddresses.sol";
import {UniswapV3OracleConfig, IUniswapV3Oracle} from "silo-oracles/contracts/uniswapV3/UniswapV3OracleConfig.sol";
import {IUniswapV3Pool} from "uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {UniswapOracleConfigDeployment} from "./_UniswapOracleConfigDeployment.sol";

abstract contract UniswapOracleConfigDeploy is SiloAddresses {
    string constant public DEPLOYMENTS_FILE =
        "silo-oracles/deploy/uniswap-v3-oracle/configs/_deployments.json";

    struct DeploymentConfig {
        string name;
        address pool;
        address quoteToken;
        uint32 periodForAvgPrice;
        uint8 blockTime;
        uint16 requiredCardinality;
    }

    function run() public returns (UniswapV3OracleConfig deployed) {
        DeploymentConfig memory config = getConfig();

        IUniswapV3Oracle.UniswapV3DeploymentConfig memory oracleConfig = IUniswapV3Oracle.UniswapV3DeploymentConfig({
            pool: IUniswapV3Pool(config.pool),
            quoteToken: config.quoteToken,
            periodForAvgPrice: config.periodForAvgPrice,
            blockTime: config.blockTime
        });

        deployed = new UniswapV3OracleConfig(
            oracleConfig,
            config.requiredCardinality
        );

        UniswapOracleConfigDeployment.save(getChainAlias(), config.name, address(deployed));
    }

    function getConfig() public view virtual returns (DeploymentConfig memory config) {}
}
