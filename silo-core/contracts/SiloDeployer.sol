// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Clones} from "openzeppelin5/proxy/Clones.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {IInterestRateModelV2} from "silo-core/contracts/interfaces/IInterestRateModelV2.sol";
import {IInterestRateModelV2Factory} from "silo-core/contracts/interfaces/IInterestRateModelV2Factory.sol";
import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";
import {ISiloDeployer} from "silo-core/contracts/interfaces/ISiloDeployer.sol";
import {SiloConfig} from "silo-core/contracts/SiloConfig.sol";
import {CloneDeterministic} from "silo-core/contracts/lib/CloneDeterministic.sol";
import {Views} from "silo-core/contracts/lib/Views.sol";
import {Create2Factory} from "common/utils/Create2Factory.sol";

/// @notice Silo Deployer
contract SiloDeployer is Create2Factory, ISiloDeployer {
    // solhint-disable var-name-mixedcase
    IInterestRateModelV2Factory public immutable IRM_CONFIG_FACTORY;
    ISiloFactory public immutable SILO_FACTORY;
    address public immutable SILO_IMPL;
    address public immutable SHARE_PROTECTED_COLLATERAL_TOKEN_IMPL;
    address public immutable SHARE_DEBT_TOKEN_IMPL;
    // solhint-enable var-name-mixedcase

    constructor(
        IInterestRateModelV2Factory _irmConfigFactory,
        ISiloFactory _siloFactory,
        address _siloImpl,
        address _shareProtectedCollateralTokenImpl,
        address _shareDebtTokenImpl
    ) {
        IRM_CONFIG_FACTORY = _irmConfigFactory;
        SILO_FACTORY = _siloFactory;
        SILO_IMPL = _siloImpl;
        SHARE_PROTECTED_COLLATERAL_TOKEN_IMPL = _shareProtectedCollateralTokenImpl;
        SHARE_DEBT_TOKEN_IMPL = _shareDebtTokenImpl;
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
        // setUp IRMs (create if needed) and update `_siloInitData`
        _setUpIRMs(_irmConfigData0, _irmConfigData1, _siloInitData);
        // create oracles and update `_siloInitData`
        _createOracles(_siloInitData, _oracles);
        // clone hook receiver if needed
        _cloneHookReceiver(_siloInitData, _clonableHookReceiver.implementation);
        // deploy `SiloConfig` (with predicted addresses)
        siloConfig = _deploySiloConfig(_siloInitData);
        // create silo
        SILO_FACTORY.createSilo({
            _siloConfig: siloConfig,
            _siloImpl: SILO_IMPL,
            _shareProtectedCollateralTokenImpl: SHARE_PROTECTED_COLLATERAL_TOKEN_IMPL,
            _shareDebtTokenImpl: SHARE_DEBT_TOKEN_IMPL,
            _deployer: _siloInitData.deployer,
            _creator: msg.sender
        });
        // initialize hook receiver only if it was cloned
        _initializeHookReceiver(_siloInitData, siloConfig, _clonableHookReceiver);

        emit SiloCreated(siloConfig);
    }

    /// @notice Deploy `SiloConfig` with predicted addresses
    /// @param _siloInitData Silo configuration for the silo creation
    /// @return siloConfig Deployed `SiloConfig`
    function _deploySiloConfig(ISiloConfig.InitData memory _siloInitData) internal returns (ISiloConfig siloConfig) {
        uint256 creatorSiloCounter = SILO_FACTORY.creatorSiloCounter(msg.sender);

        ISiloConfig.ConfigData memory configData0;
        ISiloConfig.ConfigData memory configData1;

        (configData0, configData1) = Views.copySiloConfig(
            _siloInitData,
            SILO_FACTORY.daoFeeRange(),
            SILO_FACTORY.maxDeployerFee(),
            SILO_FACTORY.maxFlashloanFee(),
            SILO_FACTORY.maxLiquidationFee()
        );

        configData0.silo = CloneDeterministic.predictSilo0Addr(
            SILO_IMPL,
            creatorSiloCounter,
            address(SILO_FACTORY),
            msg.sender
        );

        configData1.silo = CloneDeterministic.predictSilo1Addr(
            SILO_IMPL,
            creatorSiloCounter,
            address(SILO_FACTORY),
            msg.sender
        );

        configData0.collateralShareToken = configData0.silo;
        configData1.collateralShareToken = configData1.silo;

        configData0.protectedShareToken = CloneDeterministic.predictShareProtectedCollateralToken0Addr(
            SHARE_PROTECTED_COLLATERAL_TOKEN_IMPL,
            creatorSiloCounter,
            address(SILO_FACTORY),
            msg.sender
        );

        configData1.protectedShareToken = CloneDeterministic.predictShareProtectedCollateralToken1Addr(
            SHARE_PROTECTED_COLLATERAL_TOKEN_IMPL,
            creatorSiloCounter,
            address(SILO_FACTORY),
            msg.sender
        );

        configData0.debtShareToken = CloneDeterministic.predictShareDebtToken0Addr(
            SHARE_DEBT_TOKEN_IMPL,
            creatorSiloCounter,
            address(SILO_FACTORY),
            msg.sender
        );

        configData1.debtShareToken = CloneDeterministic.predictShareDebtToken1Addr(
            SHARE_DEBT_TOKEN_IMPL,
            creatorSiloCounter,
            address(SILO_FACTORY),
            msg.sender
        );

        uint256 nextSiloId = SILO_FACTORY.getNextSiloId();

        siloConfig = ISiloConfig(address(new SiloConfig{salt: _salt()}(nextSiloId, configData0, configData1)));
    }

    /// @notice Create IRMs and update `_siloInitData`
    /// @param _irmConfigData0 IRM config data for a silo `_TOKEN0`
    /// @param _irmConfigData1 IRM config data for a silo `_TOKEN1`
    /// @param _siloInitData Silo configuration for the silo creation
    function _setUpIRMs(
        IInterestRateModelV2.Config calldata _irmConfigData0,
        IInterestRateModelV2.Config calldata _irmConfigData1,
        ISiloConfig.InitData memory _siloInitData
    ) internal {
        bytes32 irmFactorySalt = _salt();

        (, IInterestRateModelV2 interestRateModel0) = IRM_CONFIG_FACTORY.create(_irmConfigData0, irmFactorySalt);
        (, IInterestRateModelV2 interestRateModel1) = IRM_CONFIG_FACTORY.create(_irmConfigData1, irmFactorySalt);

        _siloInitData.interestRateModel0 = address(interestRateModel0);
        _siloInitData.interestRateModel1 = address(interestRateModel1);
    }

    /// @notice Create an oracle if it is not specified in the `_siloInitData` and has tx details for the creation
    /// @param _siloInitData Silo configuration for the silo creation
    /// @param _oracles Oracles creation details (factory and creation tx input)
    function _createOracles(ISiloConfig.InitData memory _siloInitData, Oracles memory _oracles) internal {
        if (_siloInitData.solvencyOracle0 == address(0)) {
            _siloInitData.solvencyOracle0 = _createOracle(_oracles.solvencyOracle0);
        }

        if (_siloInitData.maxLtvOracle0 == address(0)) {
            _siloInitData.maxLtvOracle0 = _createOracle(_oracles.maxLtvOracle0);
        }

        if (_siloInitData.solvencyOracle1 == address(0)) {
            _siloInitData.solvencyOracle1 = _createOracle(_oracles.solvencyOracle1);
        }

        if (_siloInitData.maxLtvOracle1 == address(0)) {
            _siloInitData.maxLtvOracle1 = _createOracle(_oracles.maxLtvOracle1);
        }
    }

    /// @notice Create an oracle
    /// @param _txData Oracle creation details (factory and creation tx input)
    function _createOracle(OracleCreationTxData memory _txData) internal returns (address _oracle) {
        if (_txData.deployed != address(0)) return _txData.deployed;

        address factory = _txData.factory;

        if (factory == address(0)) return address(0);

        _updateSalt(_txData.txInput);

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory data) = factory.call(_txData.txInput);

        require(success && data.length == 32, FailedToCreateAnOracle(factory));

        _oracle = address(uint160(uint256(bytes32(data))));
    }

    /// @notice Clone hook receiver if it is provided
    /// @param _siloInitData Silo configuration for the silo creation
    /// @param _hookReceiverImplementation Hook receiver implementation to clone
    function _cloneHookReceiver(
        ISiloConfig.InitData memory _siloInitData,
        address _hookReceiverImplementation
    ) internal {
        require(
            _hookReceiverImplementation == address(0) || _siloInitData.hookReceiver == address(0),
            HookReceiverMisconfigured()
        );

        if (_hookReceiverImplementation != address(0)) {
            _siloInitData.hookReceiver = Clones.cloneDeterministic(_hookReceiverImplementation, _salt());
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

    /// @notice Update the salt of the tx input
    /// @param _txInput The tx input for the oracle factory
    function _updateSalt(bytes memory _txInput) internal {
        bytes32 salt = _salt();

        assembly { // solhint-disable-line no-inline-assembly
            let pointer := add(add(_txInput, 0x20), sub(mload(_txInput), 0x20))
            mstore(pointer, salt)
        }
    }
}
