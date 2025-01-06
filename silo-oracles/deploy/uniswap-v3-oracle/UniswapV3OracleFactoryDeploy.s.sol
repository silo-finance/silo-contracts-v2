// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;

import {IUniswapV3Factory} from  "uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";
import {UniswapV3OracleFactory} from "silo-oracles/contracts/uniswapV3/UniswapV3OracleFactory.sol";

/**
ETHERSCAN_API_KEY=$ARBISCAN_API_KEY FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/uniswap-v3-oracle/UniswapV3OracleFactoryDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545 --verify
 */
contract UniswapV3OracleFactoryDeploy is CommonDeploy {
    function run() public returns (UniswapV3OracleFactory factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address uniswapFactory = getAddress(AddrKey.UNISWAP_FACTORY);

        vm.startBroadcast(deployerPrivateKey);

        factory = new UniswapV3OracleFactory(IUniswapV3Factory(uniswapFactory));
        
        vm.stopBroadcast();

        _registerDeployment(address(factory), SiloOraclesFactoriesContracts.UNISWAP_V3_ORACLE_FACTORY);
    }
}
