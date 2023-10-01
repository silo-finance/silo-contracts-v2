// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

import {SiloAddrKey} from "common/SiloAddresses.sol";
import {CommonDeploy} from "./CommonDeploy.sol";

import {UniswapOneMoreConfigDeploy} from "silo-oracles/deploy/uniswap-v3-oracle/configs/UniswapOneMoreConfigDeploy.s.sol";
import {UniswapV3EthUsdcConfigDeploy} from "silo-oracles/deploy/uniswap-v3-oracle/configs/UniswapV3EthUsdcConfigDeploy.s.sol";
import {UniswapV3OracleFactoryDeploy} from "silo-oracles/deploy/uniswap-v3-oracle/UniswapV3OracleFactoryDeploy.s.sol";
import {SiloOraclesContracts} from "./SiloOraclesContracts.sol";

import {Deployments} from "silo-foundry-utils/lib/Deployments.sol";

// ONLY FOR TEST IT WILL BE REMOVED

import {console} from "forge-std/console.sol";

/**
FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/TestDeploymentThatWillBeRemoved.sol \
    --tc TestDeploymentThatWillBeRemoved --ffi --rpc-url http://127.0.0.1:8545
 */
contract TestDeploymentThatWillBeRemoved is CommonDeploy {
    function run() public {
        // set test data for the local deployment
        setAddress(31337, SiloAddrKey.USDC_ETH_UNI_POOL, address(1));
        setAddress(31337, SiloAddrKey.USDC, address(2));
        setAddress(31337, SiloAddrKey.UNISWAP_FACTORY, address(3));

        UniswapOneMoreConfigDeploy config1 = new UniswapOneMoreConfigDeploy();
        UniswapV3EthUsdcConfigDeploy config2 = new UniswapV3EthUsdcConfigDeploy();
        UniswapV3OracleFactoryDeploy factory = new UniswapV3OracleFactoryDeploy();

        // Deployments.disableDeploymentsSync();

        config1.run();
        config2.run();
        factory.run();

        // resolve deployed smart contracts addresses
        // only for tests when deployments are disabled

        address config1Addr = getAddress(config1.getConfig().name);
        address config2Addr = getAddress(config2.getConfig().name);
        address factoryAddr = getDeployedAddress(SiloOraclesContracts.UNISWAP_V3_ORACLE_FACTORY);

        console.log("config1Addr", config1Addr);
        console.log("config2Addr", config2Addr);
        console.log("factoryAddr", factoryAddr);
    }
}
