// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {IUniswapV3Factory} from  "uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";
import {ChainlinkV3OracleFactory} from "silo-oracles/contracts/chainlinkV3/ChainlinkV3OracleFactory.sol";

/**
FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/chainlink-v3-oracle/ChainlinkV3OracleFactoryDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract ChainlinkV3OracleFactoryDeploy is CommonDeploy {
    function run() public returns (ChainlinkV3OracleFactory factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);

        factory = new ChainlinkV3OracleFactory();
        
        vm.stopBroadcast();

        _registerDeployment(address(factory), SiloOraclesFactoriesContracts.CHAINLINK_V3_ORACLE_FACTORY);
    }
}
