// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

import {SiloAddrKey} from "common/SiloAddresses.sol";
import {CommonDeploy} from "./CommonDeploy.sol";

import {UniswapOneMoreConfigDeploy} from "silo-oracles/deploy/uniswap-v3-oracle/configs/UniswapOneMoreConfigDeploy.s.sol";
import {UniswapV3EthUsdcConfigDeploy} from "silo-oracles/deploy/uniswap-v3-oracle/configs/UniswapV3EthUsdcConfigDeploy.s.sol";
import {UniswapV3OracleFactoryDeploy} from "silo-oracles/deploy/uniswap-v3-oracle/UniswapV3OracleFactoryDeploy.s.sol";
import {UniswapOracleConfigDeployment} from "./uniswap-v3-oracle/configs/_UniswapOracleConfigDeployment.sol";
import {SiloOraclesContracts} from "./SiloOraclesContracts.sol";

import {Deployments} from "silo-foundry-utils/lib/Deployments.sol";
import {AddressesCollectionImpl} from "silo-foundry-utils/networks/addresses/AddressesCollectionImpl.sol";

import {UniswapOracleConfig} from "silo-oracles/deploy/uniswap-v3-oracle/configs/_UniswapOracleConfigDeployment.sol";

// ONLY FOR TEST IT WILL BE REMOVED

import {console} from "forge-std/console.sol";

/**
FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/TestDeployedAddressesFromArtifactsWillBeRemoved.sol \
    --ffi --rpc-url http://127.0.0.1:8545
 */
contract TestDeployedAddressesFromArtifactsWillBeRemoved is CommonDeploy {
    function run() public {
        address config1Addr = UniswapOracleConfigDeployment.get(getChainAlias(), UniswapOracleConfig.ETH_USDC_0_3);
        address config2Addr = UniswapOracleConfigDeployment.get(getChainAlias(), "Some_other_config_2");
        address factoryAddr = getDeployedAddress(SiloOraclesContracts.UNISWAP_V3_ORACLE_FACTORY);

        console.log("config1Addr", config1Addr);
        console.log("config2Addr", config2Addr);
        console.log("factoryAddr", factoryAddr);
    }
}
