// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {console2} from "forge-std/console2.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";
import {InterestRateModelKinkConfigData} from "../input-readers/InterestRateModelKinkConfigData.sol";
import {SiloConfigData, ISiloConfig} from "../input-readers/SiloConfigData.sol";
import {SiloDeployments} from "./SiloDeployments.sol";
import {ISiloDeployer} from "silo-core/contracts/interfaces/ISiloDeployer.sol";
import {SiloDeployerKink} from "silo-core/contracts/interestRateModel/kink/SiloDeployerKink.sol";

import {SiloDeploy} from "./SiloDeploy.s.sol";

/// @dev use `SiloDeployWithDeployerOwnerKink` or `SiloDeployWithHookReceiverOwnerKink`
abstract contract SiloDeployKink is SiloDeploy {
    function run() public virtual override returns (ISiloConfig siloConfig) {
        console2.log("[SiloDeployKink] run()");

        SiloConfigData siloData = new SiloConfigData();
        console2.log("[SiloDeployKink] SiloConfigData deployed");

        configName = bytes(configName).length == 0 ? vm.envString("CONFIG") : configName;

        console2.log("[SiloDeployKink] using CONFIG: ", configName);

        (
            SiloConfigData.ConfigData memory config,
            ISiloConfig.InitData memory siloInitData,
            address hookReceiverImplementation
        ) = siloData.getConfigData(configName);

        console2.log("[SiloDeployKink] Config prepared");

        InterestRateModelKinkConfigData modelData = new InterestRateModelKinkConfigData();

        bytes memory irmConfigData0 = modelData.getConfigData(config.interestRateModelConfig0);
        bytes memory irmConfigData1 = modelData.getConfigData(config.interestRateModelConfig1);

        console2.log("[SiloDeployKink] IRM configs prepared");

        ISiloDeployer.Oracles memory oracles = _getOracles(config, siloData);
        siloInitData.solvencyOracle0 = oracles.solvencyOracle0.deployed;
        siloInitData.maxLtvOracle0 = oracles.maxLtvOracle0.deployed;
        siloInitData.solvencyOracle1 = oracles.solvencyOracle1.deployed;
        siloInitData.maxLtvOracle1 = oracles.maxLtvOracle1.deployed;

        uint256 deployerPrivateKey = privateKey == 0 ? uint256(vm.envBytes32("PRIVATE_KEY")) : privateKey;

        console2.log("[SiloDeployKink] siloInitData.token0 before", siloInitData.token0);
        console2.log("[SiloDeployKink] siloInitData.token1 before", siloInitData.token1);

        hookReceiverImplementation = beforeCreateSilo(siloInitData, hookReceiverImplementation);

        console2.log("[SiloDeployKink] `beforeCreateSilo` executed");

        SiloDeployerKink siloDeployer =
            SiloDeployerKink(_resolveDeployedContract(SiloCoreContracts.SILO_DEPLOYER_KINK));

        console2.log("[SiloDeployKink] siloInitData.token0", siloInitData.token0);
        console2.log("[SiloDeployKink] siloInitData.token1", siloInitData.token1);
        console2.log("[SiloDeployKink] hookReceiverImplementation", hookReceiverImplementation);

        ISiloDeployer.ClonableHookReceiver memory hookReceiver;
        hookReceiver = _getClonableHookReceiverConfig(hookReceiverImplementation);

        vm.startBroadcast(deployerPrivateKey);

        siloConfig = siloDeployer.deploy(
            oracles,
            irmConfigData0,
            irmConfigData1,
            hookReceiver,
            siloInitData
        );

        vm.stopBroadcast();

        console2.log("[SiloDeployKink] deploy done");

        SiloDeployments.save(ChainsLib.chainAlias(), configName, address(siloConfig));

        _saveOracles(siloConfig, config, siloData.NO_ORACLE_KEY());

        console2.log("[SiloDeployKink] run() finished.");

        _printAndValidateDetails(siloConfig, siloInitData);
    }

    // TODO we using a low of helper methods is tests, check if we should adjust tests and use this deployer?
    // for sure for new onces.
}
