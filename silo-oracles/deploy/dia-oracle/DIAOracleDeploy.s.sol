// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";
import {DIAOraclesConfigsParser as ConfigParser} from "./DIAOraclesConfigsParser.sol";
import {IDIAOracle} from "silo-oracles/contracts/interfaces/IDIAOracle.sol";
import {DIAOracleFactory} from "silo-oracles/contracts/dia/DIAOracleFactory.sol";
import {DIAOracle} from "silo-oracles/contracts/dia/DIAOracle.sol";
import {OraclesDeployments} from "../OraclesDeployments.sol";

/**
FOUNDRY_PROFILE=oracles CONFIG=DIA_PEAS_USD \
    forge script silo-oracles/deploy/dia-oracle/DIAOracleDeploy.s.sol \
     --rpc-url $RPC_ARBITRUM --ffi --broadcast --verify
 */
contract DIAOracleDeploy is CommonDeploy {
    function run() public returns (DIAOracle oracle) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        string memory configName = vm.envString("CONFIG");

        IDIAOracle.DIADeploymentConfig memory config = ConfigParser.getConfig(
            getChainAlias(),
            configName
        );

        address factory = getDeployedAddress(SiloOraclesFactoriesContracts.DIA_ORACLE_FACTORY);

        vm.startBroadcast(deployerPrivateKey);

        oracle = DIAOracleFactory(factory).create(config, bytes32(0));

        vm.stopBroadcast();

        OraclesDeployments.save(getChainAlias(), configName, address(oracle));
    }
}
