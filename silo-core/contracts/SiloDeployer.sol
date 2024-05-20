// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Clones} from "openzeppelin5/proxy/Clones.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {IInterestRateModelV2} from "silo-core/contracts/interfaces/IInterestRateModelV2.sol";
import {IInterestRateModelV2ConfigFactory} from "silo-core/contracts/interfaces/IInterestRateModelV2ConfigFactory.sol";
import {IInterestRateModelV2Config} from "silo-core/contracts/interfaces/IInterestRateModelV2Config.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IHookReceiver} from "silo-core/contracts/utils/hook-receivers/interfaces/IHookReceiver.sol";
import {ISiloDeployer} from "silo-core/contracts/interfaces/ISiloDeployer.sol";

/// @notice Silo Deployer
contract SiloDeployer is ISiloDeployer {
    // solhint-disable var-name-mixedcase
    IInterestRateModelV2ConfigFactory public immutable IRM_CONFIG_FACTORY;
    ISiloFactory public immutable SILO_FACTORY;
    // solhint-enable var-name-mixedcase

    constructor(
        IInterestRateModelV2ConfigFactory _irmConfigFactory,
        ISiloFactory _siloFactory
    ) {
        IRM_CONFIG_FACTORY = _irmConfigFactory;
        SILO_FACTORY = _siloFactory;
    }

    /// @inheritdoc ISiloDeployer
    function deploy(
        Oracles calldata _oracles,
        IInterestRateModelV2.Config calldata _irmConfigData0,
        IInterestRateModelV2.Config calldata _irmConfigData1,
        ClonableHookReceiver calldata _clonableHookReceiver,
        ISiloConfig.InitData memory _siloInitData
    )
        external
        returns (ISiloConfig siloConfig)
    {
        // setUp IRMs (create configs) and update `_siloInitData`
        _setUpIRMs(_irmConfigData0, _irmConfigData1, _siloInitData);
        // create oracles and update `_siloInitData`
        _createOracles(_siloInitData, _oracles);
        // clone hook receiver if needed
        _cloneHookReceiver(_siloInitData, _clonableHookReceiver.implementation);
        // create Silo
        siloConfig = SILO_FACTORY.createSilo(_siloInitData);
        // initialize hook receiver only if it was cloned
        _initializeHookReceiver(_siloInitData, siloConfig, _clonableHookReceiver);

        emit SiloCreated(siloConfig);
    }

    /// @notice Create IRMs configs and update `_siloInitData`
    /// @param _irmConfigData0 IRM config data for a silo `_TOKEN0`
    /// @param _irmConfigData1 IRM config data for a silo `_TOKEN1`
    /// @param _siloInitData Silo configuration for the silo creation
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

    /// @notice Create an oracle if it is not specified in the `_siloInitData` and has tx details for the creation
    /// @param _siloInitData Silo configuration for the silo creation
    /// @param _oracles Oracles creation details (factory and creation tx input)
    function _createOracles(ISiloConfig.InitData memory _siloInitData, Oracles memory _oracles) internal {
        _siloInitData.solvencyOracle0 = _siloInitData.solvencyOracle0 != address(0)
            ? _siloInitData.solvencyOracle0
            : _createOracle(_oracles.solvencyOracle0);

        _siloInitData.maxLtvOracle0 = _siloInitData.maxLtvOracle0 != address(0)
            ? _siloInitData.maxLtvOracle0
            : _createOracle(_oracles.maxLtvOracle0);

        _siloInitData.solvencyOracle1 = _siloInitData.solvencyOracle1 != address(0)
            ? _siloInitData.solvencyOracle1
            : _createOracle(_oracles.solvencyOracle1);

        _siloInitData.maxLtvOracle1 = _siloInitData.maxLtvOracle1 != address(0)
            ? _siloInitData.maxLtvOracle1
            : _createOracle(_oracles.maxLtvOracle1);
    }

    /// @notice Create an oracle
    /// @param _txData Oracle creation details (factory and creation tx input)
    function _createOracle(OracleCreationTxData memory _txData) internal returns (address _oracle) {
        address factory = _txData.factory;

        if (factory == address(0)) return address(0);

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory data) = factory.call(_txData.txInput);

        if (!success || data.length != 32) revert FailedToCreateAnOracle(factory);

        _oracle = address(uint160(uint256(bytes32(data))));
    }

    /// @notice Clone hook receiver if it is provided
    /// @param _siloInitData Silo configuration for the silo creation
    /// @param _hookReceiverImplementation Hook receiver implementation to clone
    function _cloneHookReceiver(
        ISiloConfig.InitData memory _siloInitData,
        address _hookReceiverImplementation
    ) internal {
        if (_hookReceiverImplementation != address(0) && _siloInitData.hookReceiver != address(0)) {
            revert HookReceiverMissconfigured();
        }

        if (_hookReceiverImplementation != address(0)) {
            _siloInitData.hookReceiver = Clones.clone(_hookReceiverImplementation);
        }
    }

    /// @notice Initialize hook receiver if it was cloned
    /// @param _siloInitData Silo configuration for the silo creation
    /// (where _siloInitData.hookReceiver is the cloned hook receiver)
    /// @param _siloConfig Configuration of the created silo
    /// @param _clonableHookReceiver Hook receiver implementation and initialization data
    function _initializeHookReceiver(
        ISiloConfig.InitData memory _siloInitData,
        ISiloConfig _siloConfig,
        ClonableHookReceiver calldata _clonableHookReceiver
    ) internal {
        if (_clonableHookReceiver.implementation != address(0)) {
            IHookReceiver(_siloInitData.hookReceiver).initialize(
                _siloConfig,
                _clonableHookReceiver.initializationData
            );
        }
    }
}
