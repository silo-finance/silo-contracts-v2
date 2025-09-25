// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CustomConversionOracleFactory} from "silo-oracles/contracts/erc4626/CustomConversionOracleFactory.sol";
import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";

/**
    FOUNDRY_PROFILE=oracles \
        forge script silo-oracles/deploy/erc4626/CustomConversionOracleFactoryDeploy.sol \
        --ffi --rpc-url $RPC_SONIC --broadcast --verify
 */
contract CustomConversionOracleFactoryDeploy is CommonDeploy {
    function run() public returns (address factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        factory = address(new CustomConversionOracleFactory());

        vm.stopBroadcast();

        _registerDeployment(factory, SiloOraclesFactoriesContracts.CUSTOM_CONVERSION_ORACLE_FACTORY);
    }
}
