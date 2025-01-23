// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IUniswapV3Factory} from  "uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";
import {DIAOracleFactory} from "silo-oracles/contracts/dia/DIAOracleFactory.sol";

/**
ETHERSCAN_API_KEY=$ARBISCAN_API_KEY FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/dia-oracle/DIAOracleFactoryDeploy.s.sol \
    --ffi $RPC_SONIC --broadcast --verify
 */
contract DIAOracleFactoryDeploy is CommonDeploy {
    function run() public returns (DIAOracleFactory factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);

        factory = new DIAOracleFactory();
        
        vm.stopBroadcast();

        _registerDeployment(address(factory), SiloOraclesFactoriesContracts.DIA_ORACLE_FACTORY);
    }
}
