// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {console2} from "forge-std/console2.sol";

import {CommonDeploy, SiloCoreContracts} from "../_CommonDeploy.sol";

import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IHookReceiver} from "silo-core/contracts/utils/hook-receivers/interfaces/IHookReceiver.sol";
import {IInterestRateModelV2} from "silo-core/contracts/interfaces/IInterestRateModelV2.sol";
import {IInterestRateModelV2ConfigFactory} from "silo-core/contracts/interfaces/IInterestRateModelV2ConfigFactory.sol";
import {IInterestRateModelV2Config} from "silo-core/contracts/interfaces/IInterestRateModelV2Config.sol";
import {InterestRateModelConfigData} from "../input-readers/InterestRateModelConfigData.sol";
import {SiloConfigData, ISiloConfig} from "../input-readers/SiloConfigData.sol";
import {SiloDeployments} from "./SiloDeployments.sol";

/**
FOUNDRY_PROFILE=core CONFIG=USDC_UniswapV3_Silo \
    forge script silo-core/deploy/silo/SiloDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract SiloDeploy is CommonDeploy {
    function run() public returns (ISiloConfig siloConfig) {
        console2.log("[SiloCommonDeploy] run()");

        SiloConfigData siloData = new SiloConfigData();
        console2.log("[SiloCommonDeploy] SiloConfigData deployed");

        string memory configName = vm.envString("CONFIG");

        (SiloConfigData.ConfigData memory config, ISiloConfig.InitData memory siloInitData) =
            siloData.getConfigData(configName);

        _setUpIRMs(config, siloInitData);

        ISiloFactory siloFactory = ISiloFactory(getDeployedAddress(SiloCoreContracts.SILO_FACTORY));
        console2.log("[SiloCommonDeploy] using siloFactory %s", address(siloFactory));

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);

        beforeCreateSilo(siloInitData);
        siloConfig = siloFactory.createSilo(siloInitData);

        _initializeHooksReceivers(siloConfig, siloInitData.deployer);

        vm.stopBroadcast();

        SiloDeployments.save(getChainAlias(), configName, address(siloConfig));

        console2.log("[SiloCommonDeploy] run() finished.");
    }

    function _setUpIRMs(SiloConfigData.ConfigData memory _config, ISiloConfig.InitData memory _siloInitData) internal {
        InterestRateModelConfigData modelData = new InterestRateModelConfigData();
        console2.log("[SiloCommonDeploy] InterestRateModelConfigData deployed");

        IInterestRateModelV2ConfigFactory configFactory = IInterestRateModelV2ConfigFactory(
            getDeployedAddress(SiloCoreContracts.INTEREST_RATE_MODEL_V2_CONFIG_FACTORY)
        );

        console2.log("[SiloCommonDeploy] using configFactory %s", address(configFactory));

        (, IInterestRateModelV2Config interestRateModelConfig0) =
            configFactory.create(modelData.getConfigData(_config.interestRateModelConfig0));
        (, IInterestRateModelV2Config interestRateModelConfig1) =
            configFactory.create(modelData.getConfigData(_config.interestRateModelConfig1));

        address interestRateModel = getDeployedAddress(SiloCoreContracts.INTEREST_RATE_MODEL_V2);
        console2.log("[SiloCommonDeploy] using interestRateModel %s", address(interestRateModel));

        _siloInitData.interestRateModel0 = interestRateModel;
        _siloInitData.interestRateModelConfig0 = address(interestRateModelConfig0);

        _siloInitData.interestRateModel1 = interestRateModel;
        _siloInitData.interestRateModelConfig1 = address(interestRateModelConfig1);
    }

    function _initializeHooksReceivers(ISiloConfig _siloConfig, address _deployer) internal {
        (address silo, address otherSilo) = _siloConfig.getSilos();

        _initializeHookReceiversForSilo(_siloConfig, _deployer, silo);
        _initializeHookReceiversForSilo(_siloConfig, _deployer, otherSilo);
    }

    function _initializeHookReceiversForSilo(ISiloConfig _siloConfig, address _deployer, address _silo) internal {
        address protectedShareToken;
        address collateralShareToken;
        address debtShareToken;

        (protectedShareToken, collateralShareToken, debtShareToken) = _siloConfig.getShareTokens(_silo);

        _initializeHookReceiverForToken(_deployer, IShareToken(protectedShareToken));
        _initializeHookReceiverForToken(_deployer, IShareToken(collateralShareToken));
        _initializeHookReceiverForToken(_deployer, IShareToken(debtShareToken));
    }

    function _initializeHookReceiverForToken(address _deployer, IShareToken _token) internal {
        address hookReceiver = _token.hookReceiver();

        if (hookReceiver != address(0)) {
            IHookReceiver(hookReceiver).initialize(_deployer, _token);
        }
    }

    function beforeCreateSilo(ISiloConfig.InitData memory) internal virtual {
        // hook for any action before creating silo
    }
}
