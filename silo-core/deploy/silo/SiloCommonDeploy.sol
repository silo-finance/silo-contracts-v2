// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {CommonDeploy, SiloCoreContracts} from "../_CommonDeploy.sol";

import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {IInterestRateModelV2} from "silo-core/contracts/interfaces/IInterestRateModelV2.sol";
import {IInterestRateModelV2ConfigFactory} from "silo-core/contracts/interfaces/IInterestRateModelV2ConfigFactory.sol";
import {IInterestRateModelV2Config} from "silo-core/contracts/interfaces/IInterestRateModelV2Config.sol";
import {InterestRateModelConfigData} from "../input-readers/InterestRateModelConfigData.sol";
import {SiloConfigData, ISiloConfig} from "../input-readers/SiloConfigData.sol";

abstract contract SiloCommonDeploy is CommonDeploy {
    function run() public returns (ISiloConfig siloConfig) {
        SiloConfigData siloData = new SiloConfigData();
        InterestRateModelConfigData modelData = new InterestRateModelConfigData();

        (SiloConfigData.ConfigData memory config, ISiloConfig.InitData memory siloInitData) =
            siloData.getConfigData(siloToDeploy());

        IInterestRateModelV2ConfigFactory configFactory = IInterestRateModelV2ConfigFactory(
            getDeployedAddress(SiloCoreContracts.INTEREST_RATE_MODEL_V2_CONFIG_FACTORY)
        );

        (, IInterestRateModelV2Config interestRateModelConfig0) =
            configFactory.create(modelData.getConfigData(config.interestRateModelConfig0));
        (, IInterestRateModelV2Config interestRateModelConfig1) =
            configFactory.create(modelData.getConfigData(config.interestRateModelConfig1));

        address interestRateModel = getDeployedAddress(SiloCoreContracts.INTEREST_RATE_MODEL_V2);

        // TODO: pull and set all the data below
        // siloInitData.solvencyOracle0
        // siloInitData.maxLtvOracle0
        // siloInitData.protectedHookReceiver0
        // siloInitData.collateralHookReceiver0
        // siloInitData.debtHookReceiver0
        // siloInitData.solvencyOracle1
        // siloInitData.maxLtvOracle1
        // siloInitData.protectedHookReceiver1
        // siloInitData.collateralHookReceiver1
        // siloInitData.debtHookReceiver1

        siloInitData.interestRateModel0 = interestRateModel;
        siloInitData.interestRateModelConfig0 = address(interestRateModelConfig0);

        siloInitData.interestRateModel1 = interestRateModel;
        siloInitData.interestRateModelConfig1 = address(interestRateModelConfig1);

        ISiloFactory siloFactory = ISiloFactory(getDeployedAddress(SiloCoreContracts.SILO_FACTORY));

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        siloConfig = siloFactory.createSilo(siloInitData);

        vm.stopBroadcast();

        _registerDeployment(address(siloConfig), siloToDeploy());
        _syncDeployments();
    }

    function siloToDeploy() public pure virtual returns (string memory);
}
