// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

import {UniswapOracleConfig} from "./_UniswapOracleConfigDeployment.sol";
import {UniswapOracleConfigDeploy, SiloAddrKey} from "./_UniswapOracleConfigDeploy.sol";

/**
FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/uniswap-v3-oracle/configs/UniswapV3EthUsdcConfigDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract UniswapV3EthUsdcConfigDeploy is UniswapOracleConfigDeploy {
    function getConfig() public view override returns (DeploymentConfig memory config) {
        config = DeploymentConfig({
            name: UniswapOracleConfig.ETH_USDC_0_3,
            pool: getAddress(SiloAddrKey.USDC_ETH_UNI_POOL),
            quoteToken: getAddress(SiloAddrKey.USDC),
            periodForAvgPrice: 1800,
            blockTime: 120,
            requiredCardinality: 1
        });
    }
}
