// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console2} from "forge-std/console2.sol";

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {PTLinearOracleFactory} from "silo-oracles/contracts/pendle/linear/PTLinearOracleFactory.sol";

import {AddrKey} from "common/addresses/AddrKey.sol";
import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";

/*
FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/pendle/PTLinearOracleFactoryDeploy.s.sol \
    --ffi --rpc-url $RPC_ARBITRUM --broadcast --verify
 */
contract PTLinearOracleFactoryDeploy is CommonDeploy {
    function run() public returns (address factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address pendleLinearOracleFactory =
            AddrLib.getAddress(ChainsLib.chainAlias(), AddrKey.PENDLE_LINEAR_ORACLE_FACTORY);
        console2.log("pendleLinearOracleFactory", pendleLinearOracleFactory);
        require(pendleLinearOracleFactory != address(0), "pendleLinearOracleFactory is not set");

        vm.startBroadcast(deployerPrivateKey);

        factory = address(new PTLinearOracleFactory(pendleLinearOracleFactory));

        vm.stopBroadcast();

        _registerDeployment(factory, SiloOraclesFactoriesContracts.PT_LINEAR_ORACLE_FACTORY);
    }
}
