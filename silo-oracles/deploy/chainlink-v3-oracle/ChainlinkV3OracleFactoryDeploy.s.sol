// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IUniswapV3Factory} from  "uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";
import {ChainlinkV3OracleFactory} from "silo-oracles/contracts/chainlinkV3/ChainlinkV3OracleFactory.sol";

/**
ETHERSCAN_API_KEY=$ARBISCAN_API_KEY FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/chainlink-v3-oracle/ChainlinkV3OracleFactoryDeploy.s.sol \
    --ffi --rpc-url $RPC_SONIC --broadcast --verify

FOUNDRY_PROFILE=oracles forge verify-contract 0x17B0FD3eB9CFbdA5B46A0C896e28b3F0c5a7F61d \
    ChainlinkV3OracleFactory \
    --compiler-version 0.8.28 \
    --rpc-url $RPC_SONIC \
    --watch
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
