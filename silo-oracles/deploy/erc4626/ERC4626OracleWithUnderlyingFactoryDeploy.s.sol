// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IUniswapV3Factory} from  "uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";
import {ERC4626OracleWithUnderlyingFactory} from "silo-oracles/contracts/erc4626/ERC4626OracleWithUnderlyingFactory.sol";

/**
FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/erc4626/ERC4626OracleWithUnderlyingFactoryDeploy.s.sol \
    --ffi --rpc-url $RPC_MAINNET --broadcast --verify
 */
contract ERC4626OracleWithUnderlyingFactoryDeploy is CommonDeploy {
    function run() public returns (ERC4626OracleWithUnderlyingFactory factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);

        factory = new ERC4626OracleWithUnderlyingFactory();
        
        vm.stopBroadcast();

        _registerDeployment(address(factory), SiloOraclesFactoriesContracts.ERC4626_ORACLE_UNDERLYING_FACTORY);
    }
}
