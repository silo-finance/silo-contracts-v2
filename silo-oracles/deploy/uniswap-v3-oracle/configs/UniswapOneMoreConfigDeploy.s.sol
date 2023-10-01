// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

import {UniswapOracleConfigDeploy, SiloAddrKey} from "./_UniswapOracleConfigDeploy.sol";

// ONLY FOR TEST IT WILL BE REMOVED

/**
FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/uniswap-v3-oracle/configs/UniswapOneMoreConfigDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract UniswapOneMoreConfigDeploy is UniswapOracleConfigDeploy {
    function getConfig() public view override returns (DeploymentConfig memory config) {
        config = DeploymentConfig({
            name: "Some_other_config_2",
            pool: getAddress(SiloAddrKey.USDC_ETH_UNI_POOL),
            quoteToken: getAddress(SiloAddrKey.USDC),
            periodForAvgPrice: 1800,
            blockTime: 120,
            requiredCardinality: 1
        });
    }
}
