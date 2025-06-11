// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {console2} from "forge-std/console2.sol";
import {CommonDeploy} from "../_CommonDeploy.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {SiloCoreContracts, SiloCoreDeployments} from "silo-core/common/SiloCoreContracts.sol";
import {SiloDeployments} from "silo-core/deploy/silo/SiloDeployments.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {ChainlinkV3Oracle, ChainlinkV3OracleConfig} from "silo-oracles/contracts/chainlinkV3/ChainlinkV3Oracle.sol";
import {InterestRateModelV2} from "silo-core/contracts/interestRateModel/InterestRateModelV2.sol";
import {GaugeHookReceiver} from "silo-core/contracts/hooks/gauge/GaugeHookReceiver.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

/**
FOUNDRY_PROFILE=core \
    forge script silo-core/deploy/silo/PrintSiloAddresses.s.sol \
    --ffi --rpc-url $RPC_SONIC
 */

contract PrintSiloAddresses is CommonDeploy {
    function run() public {
        ISiloFactory siloFactory = ISiloFactory(
            SiloCoreDeployments.get(SiloCoreContracts.SILO_FACTORY, ChainsLib.chainAlias())
        );

        console2.log("All silo0 and silo1 addresses for network", ChainsLib.chainAlias());
        printSilos(siloFactory);

        console2.log("\nAll related addresses to silos, including configs, IRMs, oracles (duplicates not filtered)");
        printAllRelatedAddresses(siloFactory);
    }

    /// @dev print only silo0 and silo1 addresses for all deployed silos.
    function printSilos(ISiloFactory _siloFactory) internal view {
        uint256 i = 1;

        while (true) {
            ISiloConfig config = ISiloConfig(_siloFactory.idToSiloConfig(i));
            i++;

            if (address(config) == address(0)) break;

            (address silo0, address silo1) = config.getSilos();
            console2.log(silo0);
            console2.log(silo1);
        }
    }

    /// @dev print all related addresses for every silo: IRMs, Oracles, configs. Prints everything except silo0 and
    /// silo1 addresses.
    function printAllRelatedAddresses(ISiloFactory _siloFactory) internal view {
        uint256 i = 1;

        while (true) {
            ISiloConfig config = ISiloConfig(_siloFactory.idToSiloConfig(i));
            i++;

            if (address(config) == address(0)) break;

            (address silo0, address silo1) = config.getSilos();

            ISiloConfig.ConfigData memory siloConfig0 = config.getConfig(silo0);
            ISiloConfig.ConfigData memory siloConfig1 = config.getConfig(silo1);

            console2.log(address(config));
            printSiloConfigRelatedAddresses(siloConfig0);
            printSiloConfigRelatedAddresses(siloConfig1);
        }
    }

    /// @dev print all related addresses for SiloConfig: IRMs, Oracles, configs. Prints everything except silo0 and
    /// silo1 addresses.
    function printSiloConfigRelatedAddresses(ISiloConfig.ConfigData memory _siloConfig) internal view {
        logIfNotZero(_siloConfig.protectedShareToken); // regular share token is logged as silo address
        logIfNotZero(_siloConfig.debtShareToken);
        logIfNotZero(_siloConfig.solvencyOracle);
        tryLogChainlinkConfig(_siloConfig.solvencyOracle);
        logIfNotZero(_siloConfig.maxLtvOracle);
        tryLogChainlinkConfig(_siloConfig.maxLtvOracle);
        logIfNotZero(_siloConfig.interestRateModel);
        logIfNotZero(address(InterestRateModelV2(_siloConfig.interestRateModel).irmConfig()));

        GaugeHookReceiver hookReceiver = GaugeHookReceiver(_siloConfig.hookReceiver);
        logIfNotZero(address(hookReceiver));

        address protectedShareTokensGauge =
            address(hookReceiver.configuredGauges(IShareToken(_siloConfig.protectedShareToken)));

        address collateralShareTokensGauge =
            address(hookReceiver.configuredGauges(IShareToken(_siloConfig.collateralShareToken)));

        address debtShareTokensGauge =
            address(hookReceiver.configuredGauges(IShareToken(_siloConfig.debtShareToken)));

        logIfNotZero(protectedShareTokensGauge);
        logIfNotZero(collateralShareTokensGauge);
        logIfNotZero(debtShareTokensGauge);
    }

    function logIfNotZero(address _toLog) internal pure {
        if (_toLog != address(0)) console2.log(_toLog);
    }

    function tryLogChainlinkConfig(address _oracle) internal view {
        if (_oracle == address(0)) return;

        try ChainlinkV3Oracle(_oracle).oracleConfig() returns (ChainlinkV3OracleConfig config) {
            console2.log(address(config));
        } catch {}
    }
}
