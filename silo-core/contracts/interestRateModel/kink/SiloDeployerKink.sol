// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ownable1and2Steps} from "common/access/Ownable1and2Steps.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {IInterestRateModelV2} from "silo-core/contracts/interfaces/IInterestRateModelV2.sol";
import {IInterestRateModel} from "silo-core/contracts/interfaces/IInterestRateModel.sol";
import {IInterestRateModelFactory} from "silo-core/contracts/interfaces/IInterestRateModelFactory.sol";
import {IInterestRateModelV2Factory} from "silo-core/contracts/interfaces/IInterestRateModelV2Factory.sol";
import {ISiloDeployer} from "silo-core/contracts/interfaces/ISiloDeployer.sol";
import {SiloDeployer} from "silo-core/contracts/SiloDeployer.sol";

/// @notice Silo Deployer
contract SiloDeployerKink is SiloDeployer {
    constructor(
        IInterestRateModelFactory _irmConfigFactory,
        ISiloFactory _siloFactory,
        address _siloImpl,
        address _shareProtectedCollateralTokenImpl,
        address _shareDebtTokenImpl
    )
        SiloDeployer(
            IInterestRateModelV2Factory(address(_irmConfigFactory)),
            _siloFactory,
            _siloImpl,
            _shareProtectedCollateralTokenImpl,
            _shareDebtTokenImpl
        )
    {}

    /// @inheritdoc ISiloDeployer
    function deploy(
        Oracles calldata,
        IInterestRateModelV2.Config calldata,
        IInterestRateModelV2.Config calldata,
        ClonableHookReceiver calldata,
        ISiloConfig.InitData memory
    )
        external
        override
        virtual
        returns (ISiloConfig siloConfig)
    {
        revert("use other `deploy` function");
    }

    function deploy(
        Oracles calldata _oracles,
        bytes calldata _irmConfigData0,
        bytes calldata _irmConfigData1,
        ClonableHookReceiver calldata _clonableHookReceiver,
        ISiloConfig.InitData memory _siloInitData
    )
        external
        virtual
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

    function _setUpIRMs(
        IInterestRateModelV2.Config calldata,
        IInterestRateModelV2.Config calldata,
        ISiloConfig.InitData memory
    ) internal virtual override {
        revert("use other `_setUpIRMs` function");
    }

    /// @notice Create IRMs and update `_siloInitData`
    /// @param _irmConfigData0 IRM config data for a silo `_TOKEN0`
    /// @param _irmConfigData1 IRM config data for a silo `_TOKEN1`
    /// @param _siloInitData Silo configuration for the silo creation
    function _setUpIRMs(
        bytes calldata _irmConfigData0,
        bytes calldata _irmConfigData1,
        ISiloConfig.InitData memory _siloInitData
    ) internal virtual {
        bytes32 irmFactorySalt = _salt();

        IInterestRateModelFactory irmFactory = IInterestRateModelFactory(address(IRM_CONFIG_FACTORY));

        (, IInterestRateModel interestRateModel0) = irmFactory.create(_irmConfigData0, irmFactorySalt);
        (, IInterestRateModel interestRateModel1) = irmFactory.create(_irmConfigData1, irmFactorySalt);

        Ownable1and2Steps(address(interestRateModel0)).transferOwnership1Step(msg.sender);
        Ownable1and2Steps(address(interestRateModel1)).transferOwnership1Step(msg.sender);

        _siloInitData.interestRateModel0 = address(interestRateModel0);
        _siloInitData.interestRateModel1 = address(interestRateModel1);
    }
}
