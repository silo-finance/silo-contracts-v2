// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console2} from "forge-std/console2.sol";

import {CommonDeploy} from "../../CommonDeploy.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {SiloOraclesFactoriesContracts, SiloOraclesFactoriesDeployments} from "silo-oracles/deploy/SiloOraclesFactoriesContracts.sol";

import {IFixedPricePTAMMOracleFactory} from "silo-oracles/contracts/interfaces/IFixedPricePTAMMOracleFactory.sol";
import {IFixedPricePTAMMOracleConfig} from "silo-oracles/contracts/interfaces/IFixedPricePTAMMOracleConfig.sol";
import {IFixedPricePTAMMOracle} from "silo-oracles/contracts/interfaces/IFixedPricePTAMMOracle.sol";
import {IPendleAMM} from "silo-oracles/contracts/interfaces/IPendleAMM.sol";


abstract contract PTAmmOracleDeployCommon is CommonDeploy {
    function _deployPTAmmOracle(IFixedPricePTAMMOracleConfig.DeploymentConfig memory _config) internal {
        require(_config.hardcoddedQuoteToken != address(0), "hardcoddedQuoteToken is not set");

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        string memory chainAlias = ChainsLib.chainAlias();

        IFixedPricePTAMMOracleFactory factory = IFixedPricePTAMMOracleFactory(SiloOraclesFactoriesDeployments.get(
            SiloOraclesFactoriesContracts.FIXED_PRICE_PT_AMM_ORACLE_FACTORY,
            chainAlias
        ));

        console2.log("factory: ", address(factory));
        require(address(factory) != address(0), "factory is not deployed");

        address existingOracle = factory.resolveExistingOracle(factory.hashConfig(_config));

        console2.log("existing oracle: ", existingOracle);
        if (existingOracle != address(0)) return;

        vm.startBroadcast(deployerPrivateKey);
        IFixedPricePTAMMOracle oracle = factory.create(_config, bytes32(0));
        vm.stopBroadcast();

        console2.log("deployed oracle: ", address(oracle));

        uint256 samplePrice = oracle.quote(1e18, _config.ptToken);
        console2.log("sample price for 1e18 PT: ", samplePrice);
    }
}
