// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {FixedPricePTAMMOracleFactory} from "silo-oracles/contracts/pendle/amm/FixedPricePTAMMOracleFactory.sol";
import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";

/**
FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/pendle/FixedPricePTAMMOracleFactoryDeploy.s.sol \
    --ffi --rpc-url $RPC_AVALANCHE --broadcast --verify
 */
contract FixedPricePTAMMOracleFactoryDeploy is CommonDeploy {
    function run() public returns (address factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);

        factory = address(new FixedPricePTAMMOracleFactory());

        vm.stopBroadcast();

        _registerDeployment(factory, SiloOraclesFactoriesContracts.FIXED_PRICE_PT_AMM_ORACLE_FACTORY);
    }
}
