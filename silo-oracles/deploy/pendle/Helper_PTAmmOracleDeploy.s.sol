// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console2} from "forge-std/console2.sol";

import {CommonDeploy} from "../CommonDeploy.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {SiloOraclesFactoriesContracts, SiloOraclesFactoriesDeployments} from "silo-oracles/deploy/SiloOraclesFactoriesContracts.sol";

import {IFixedPricePTAMMOracleFactory} from "silo-oracles/contracts/interfaces/IFixedPricePTAMMOracleFactory.sol";
import {IFixedPricePTAMMOracleConfig} from "silo-oracles/contracts/interfaces/IFixedPricePTAMMOracleConfig.sol";
import {IFixedPricePTAMMOracle} from "silo-oracles/contracts/interfaces/IFixedPricePTAMMOracle.sol";
import {IPendleAMM} from "silo-oracles/contracts/interfaces/IPendleAMM.sol";

/**
FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/pendle/Helper_PTAmmOracleDeploy.s.sol \
    --ffi --rpc-url $RPC_AVALANCHE --broadcast --verify
 */
contract Helper_PTAmmOracleDeploy is CommonDeploy {
    function run() public {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        string memory chainAlias = ChainsLib.chainAlias();

        IFixedPricePTAMMOracleFactory factory = IFixedPricePTAMMOracleFactory(SiloOraclesFactoriesDeployments.get(
            SiloOraclesFactoriesContracts.FIXED_PRICE_PT_AMM_ORACLE_FACTORY,
            chainAlias
        ));

        console2.log("factory: ", address(factory));

        IFixedPricePTAMMOracleConfig.DeploymentConfig memory config = IFixedPricePTAMMOracleConfig.DeploymentConfig({
            amm: IPendleAMM(0x4d717868F4Bd14ac8B29Bb6361901e30Ae05e340),
            ptToken: 0xB4205a645c7e920BD8504181B1D7f2c5C955C3e7,
            ptUnderlyingQuoteToken: 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34,
            hardcoddedQuoteToken: 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E // USDC
        });

        address existingOracle = factory.resolveExistingOracle(factory.hashConfig(config));

        console2.log("existing oracle: ", existingOracle);
        if (existingOracle != address(0)) return;

        vm.startBroadcast(deployerPrivateKey);
        IFixedPricePTAMMOracle oracle = factory.create(config, bytes32(0));
        vm.stopBroadcast();

        console2.log("deployed oracle: ", address(oracle));
    }
}
