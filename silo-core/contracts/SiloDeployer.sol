// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {IInterestRateModelV2} from "silo-core/contracts/interfaces/IInterestRateModelV2.sol";
import {IInterestRateModelV2ConfigFactory} from "silo-core/contracts/interfaces/IInterestRateModelV2ConfigFactory.sol";
import {IHookReceiversFactory} from "silo-core/contracts/utils/hook-receivers/interfaces/IHookReceiversFactory.sol";
import {IInterestRateModelV2Config} from "silo-core/contracts/interfaces/IInterestRateModelV2Config.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IHookReceiver} from "silo-core/contracts/utils/hook-receivers/interfaces/IHookReceiver.sol";
import {ISiloDeployer} from "silo-core/contracts/interfaces/ISiloDeployer.sol";

contract SiloDeployer is ISiloDeployer {
    // solhint-disable var-name-mixedcase
    IInterestRateModelV2ConfigFactory public immutable IRM_CONFIG_FACTORY;
    ISiloFactory public immutable SILO_FACTORY;
    IHookReceiversFactory public immutable HOOK_RECEIVERS_FACTORY;
    address public immutable TIMELOCK_CONTROLLER;
    // solhint-enable var-name-mixedcase

    constructor(
        IInterestRateModelV2ConfigFactory _irmConfigFactory,
        ISiloFactory _siloFactory,
        IHookReceiversFactory _hookReceiversFactory,
        address _timelockController
    ) {
        IRM_CONFIG_FACTORY = _irmConfigFactory;
        SILO_FACTORY = _siloFactory;
        HOOK_RECEIVERS_FACTORY = _hookReceiversFactory;
        TIMELOCK_CONTROLLER = _timelockController;
    }

    function deploy(
        Oracles calldata _oracles,
        IInterestRateModelV2.Config calldata _irmConfigData0,
        IInterestRateModelV2.Config calldata _irmConfigData1,
        ISiloConfig.InitData memory _siloInitData
    )
        external
        returns (ISiloConfig siloConfig)
    {
        // setUp IRMs (create configs) and update `_siloInitData`
        _setUpIRMs(_irmConfigData0, _irmConfigData1, _siloInitData);
        // create (clone) hook receivers and update `_siloInitData`
        _createHookReceivers(_siloInitData);
        // create oracles and update `_siloInitData`
        _createOracles(_siloInitData, _oracles);
        // create Silo
        siloConfig = SILO_FACTORY.createSilo(_siloInitData);
        // initialize hook receivers
        _initializeHookReceivers(siloConfig, _siloInitData);

        emit SiloCreated(siloConfig);
    }

    function _setUpIRMs(
        IInterestRateModelV2.Config calldata _irmConfigData0,
        IInterestRateModelV2.Config calldata _irmConfigData1,
        ISiloConfig.InitData memory _siloInitData
    ) internal {
        (, IInterestRateModelV2Config interestRateModelConfig0) = IRM_CONFIG_FACTORY.create(_irmConfigData0);
        (, IInterestRateModelV2Config interestRateModelConfig1) = IRM_CONFIG_FACTORY.create(_irmConfigData1);

        _siloInitData.interestRateModelConfig0 = address(interestRateModelConfig0);
        _siloInitData.interestRateModelConfig1 = address(interestRateModelConfig1);
    }

    function _createHookReceivers(ISiloConfig.InitData memory _siloInitData) internal {
        IHookReceiversFactory.HookReceivers memory implementations = IHookReceiversFactory.HookReceivers({
            protectedHookReceiver0: _siloInitData.protectedHookReceiver0,
            collateralHookReceiver0: _siloInitData.collateralHookReceiver0,
            debtHookReceiver0: _siloInitData.debtHookReceiver0,
            protectedHookReceiver1: _siloInitData.protectedHookReceiver1,
            collateralHookReceiver1: _siloInitData.collateralHookReceiver1,
            debtHookReceiver1: _siloInitData.debtHookReceiver1
        });

        IHookReceiversFactory.HookReceivers memory clones = HOOK_RECEIVERS_FACTORY.create(implementations);

        _siloInitData.protectedHookReceiver0 = clones.protectedHookReceiver0;
        _siloInitData.collateralHookReceiver0 = clones.collateralHookReceiver0;
        _siloInitData.debtHookReceiver0 = clones.debtHookReceiver0;
        _siloInitData.protectedHookReceiver1 = clones.protectedHookReceiver1;
        _siloInitData.collateralHookReceiver1 = clones.collateralHookReceiver1;
        _siloInitData.debtHookReceiver1 = clones.debtHookReceiver1;
    }

    function _initializeHookReceivers(ISiloConfig _siloConfig, ISiloConfig.InitData memory _siloInitData) internal {
        (address silo, address otherSilo) = _siloConfig.getSilos();

        // `silo` hook receivers initialization
        HookReceivers memory hookReceivers = HookReceivers({
            protectedHookReceiver: _siloInitData.protectedHookReceiver0,
            collateralHookReceiver: _siloInitData.collateralHookReceiver0,
            debtHookReceiver: _siloInitData.debtHookReceiver0
        });

        _initializeHookReceiversForSilo(_siloConfig, hookReceivers, silo);

        // `otherSilo` hook receivers initialization
        hookReceivers = HookReceivers({
            protectedHookReceiver: _siloInitData.protectedHookReceiver1,
            collateralHookReceiver: _siloInitData.collateralHookReceiver1,
            debtHookReceiver: _siloInitData.debtHookReceiver1
        });

        _initializeHookReceiversForSilo(_siloConfig, hookReceivers, otherSilo);
    }

    function _initializeHookReceiversForSilo(
        ISiloConfig _siloConfig,
        HookReceivers memory _hookReceivers,
        address _silo
    ) internal {
        address protectedShareToken;
        address collateralShareToken;
        address debtShareToken;

        (protectedShareToken, collateralShareToken, debtShareToken) = _siloConfig.getShareTokens(_silo);

        _initializeHookReceiverForToken(protectedShareToken, _hookReceivers.protectedHookReceiver);
        _initializeHookReceiverForToken(collateralShareToken, _hookReceivers.collateralHookReceiver);
        _initializeHookReceiverForToken(debtShareToken, _hookReceivers.debtHookReceiver);
    }

    function _initializeHookReceiverForToken(address _token, address _hookReceiver) internal {
        if (_hookReceiver != address(0)) {
            IHookReceiver(_hookReceiver).initialize(TIMELOCK_CONTROLLER, IShareToken(_token));
        }
    }

    function _createOracles(ISiloConfig.InitData memory _siloInitData, Oracles memory _oracles) internal {
        _siloInitData.solvencyOracle0 = _createOracle(_oracles.solvencyOracle0);
        _siloInitData.maxLtvOracle0 = _createOracle(_oracles.maxLtvOracle0);
        _siloInitData.solvencyOracle1 = _createOracle(_oracles.solvencyOracle1);
        _siloInitData.maxLtvOracle1 = _createOracle(_oracles.maxLtvOracle1);
    }

    function _createOracle(OracleCreationTxData memory _txData) internal returns (address _oracle) {
        address factory = _txData.factory;

        if (factory == address(0)) return address(0);

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory data) = factory.call(_txData.txInput);

        if (!success || data.length != 32) revert FailedToCreateAnOracle(factory);

        _oracle = address(uint160(uint256(bytes32(data))));
    }
}
