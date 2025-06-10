// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Nonces} from "openzeppelin5/utils/Nonces.sol";
import {Clones} from "openzeppelin5/proxy/Clones.sol";
import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";
import {Create2Factory} from "common/utils/Create2Factory.sol";

import {IIncentivesClaimingLogic} from "silo-vaults/contracts/interfaces/IIncentivesClaimingLogic.sol";
import {IIncentivesClaimingLogicFactory} from "silo-vaults/contracts/interfaces/IIncentivesClaimingLogicFactory.sol";
import {ISiloVault} from "silo-vaults/contracts/interfaces/ISiloVault.sol";
import {IIncentivesClaimingLogic} from "silo-vaults/contracts/interfaces/IIncentivesClaimingLogic.sol";
import {ISiloVaultsFactory} from "silo-vaults/contracts/interfaces/ISiloVaultsFactory.sol";
import {IdleVaultsFactory} from "silo-vaults/contracts/IdleVaultsFactory.sol";
import {ISiloIncentivesController} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";
import {ISiloVaultDeployer} from "silo-vaults/contracts/interfaces/ISiloVaultDeployer.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IGaugeHookReceiver} from "silo-core/contracts/interfaces/IGaugeHookReceiver.sol";

import {
    ISiloIncentivesControllerFactory
} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesControllerFactory.sol";

import {
    ISiloIncentivesControllerCLFactory
} from "silo-vaults/contracts/interfaces/ISiloIncentivesControllerCLFactory.sol";

/// @title SiloVaultDeployer
contract SiloVaultDeployer is ISiloVaultDeployer, Create2Factory {
    ISiloVaultsFactory public immutable SILO_VAULTS_FACTORY;
    ISiloIncentivesControllerFactory public immutable SILO_INCENTIVES_CONTROLLER_FACTORY;
    ISiloIncentivesControllerCLFactory public immutable SILO_INCENTIVES_CONTROLLER_CL_FACTORY;
    IdleVaultsFactory public immutable IDLE_VAULTS_FACTORY;

    /// @dev Factories initialization
    /// @param _siloVaultsFactory The factory for deploying Silo Vaults.
    /// @param _siloIncentivesControllerFactory The factory for deploying Silo Incentives Controllers.
    /// @param _siloIncentivesControllerCLFactory The factory for deploying incentives claiming logics.
    /// @param _idleVaultsFactory The factory for deploying Idle Vaults.
    constructor(
        ISiloVaultsFactory _siloVaultsFactory,
        ISiloIncentivesControllerFactory _siloIncentivesControllerFactory,
        ISiloIncentivesControllerCLFactory _siloIncentivesControllerCLFactory,
        IdleVaultsFactory _idleVaultsFactory
    ) {
        require(address(_siloVaultsFactory) != address(0), EmptySiloVaultFactory());
        require(address(_siloIncentivesControllerCLFactory) != address(0), EmptySiloIncentivesControllerCLFactory());
        require(address(_idleVaultsFactory) != address(0), EmptyIdleVaultFactory());
        require(address(_siloIncentivesControllerFactory) != address(0), EmptySiloIncentivesControllerFactory());

        SILO_VAULTS_FACTORY = _siloVaultsFactory;
        SILO_INCENTIVES_CONTROLLER_FACTORY = _siloIncentivesControllerFactory;
        SILO_INCENTIVES_CONTROLLER_CL_FACTORY = _siloIncentivesControllerCLFactory;
        IDLE_VAULTS_FACTORY = _idleVaultsFactory;
    }

    /// @inheritdoc ISiloVaultDeployer
    function createSiloVault(CreateSiloVaultParams memory params)
        external
        returns (
            ISiloVault vault,
            ISiloIncentivesController incentivesController,
            IERC4626 idleVault
        )
    {
        bytes32 salt = _salt();

        address predictedAddress = _predictSiloVaultAddress({
            _initialOwner: params.initialOwner,
            _initialTimelock: params.initialTimelock,
            _asset: params.asset,
            _name: params.name,
            _symbol: params.symbol,
            _externalSalt: salt
        });

        // 1. Deploy Silo Incentives Controller
        incentivesController = ISiloIncentivesController(SILO_INCENTIVES_CONTROLLER_FACTORY.create({
            _owner: params.incentivesControllerOwner,
            _notifier: predictedAddress,
            _shareToken: predictedAddress,
            _externalSalt: salt
        }));

        IIncentivesClaimingLogic[] memory claimingLogics;
        IERC4626[] memory marketsWithIncentives;

        // 2. Deploy claiming logics
        (claimingLogics, marketsWithIncentives) = _deployClaimingLogics({
            _silosWithIncentives: params.silosWithIncentives,
            _salt: salt,
            _vaultIncentivesController: address(incentivesController),
            _vault: predictedAddress
        });

        // 3. Deploy Silo Vault
        vault = _deploySiloVault({
            _params: params,
            _salt: salt,
            _notificationReceiver: address(incentivesController),
            _claimingLogics: claimingLogics,
            _marketsWithIncentives: marketsWithIncentives,
            _trustedFactories: params.trustedFactories
        });

        require(address(vault) == predictedAddress, VaultAddressMismatch());

        // 4. Deploy Idle Vault
        idleVault = IERC4626(address(
            IDLE_VAULTS_FACTORY.createIdleVault({_vault: IERC4626(address(vault)), _externalSalt: salt})
        ));

        emit CreateSiloVault(address(vault), address(incentivesController), address(idleVault));
    }

    /// @dev Deploys the Silo Vault.
    /// @param _params The parameters for the deployment.
    /// @param _salt The salt for the deployment.
    /// @param _notificationReceiver The notification receiver for the pre-configuration.
    /// @param _claimingLogics The claiming logics for the pre-configuration.
    /// @param _marketsWithIncentives The markets with incentives for the pre-configuration.
    /// @param _trustedFactories The trusted factories for the pre-configuration.
    function _deploySiloVault(
        CreateSiloVaultParams memory _params,
        bytes32 _salt,
        address _notificationReceiver,
        IIncentivesClaimingLogic[] memory _claimingLogics,
        IERC4626[] memory _marketsWithIncentives,
        IIncentivesClaimingLogicFactory[] memory _trustedFactories
    ) internal returns (ISiloVault vault) {
        vault = SILO_VAULTS_FACTORY.createSiloVault({
            _initialOwner: _params.initialOwner,
            _initialTimelock: _params.initialTimelock,
            _asset: _params.asset,
            _name: _params.name,
            _symbol: _params.symbol,
            _externalSalt: _salt,
            _notificationReceiver: _notificationReceiver,
            _claimingLogics: _claimingLogics,
            _marketsWithIncentives: _marketsWithIncentives,
            _trustedFactories: _trustedFactories
        });
    }

    /// @dev Deploy claiming logic ONLY for the collateral share token
    /// @param _silosWithIncentives The silos with incentives to deploy claiming logics for.
    /// @param _salt The salt for the deployment.
    /// @param _vaultIncentivesController The vault incentives controller address.
    /// @param _vault The vault address.
    /// @return claimingLogics The deployed claiming logics.
    /// @return marketsWithIncentives The deployed markets with incentives.
    function _deployClaimingLogics(
        ISilo[] memory _silosWithIncentives,
        bytes32 _salt,
        address _vaultIncentivesController,
        address _vault
    )
        internal
        returns (
            IIncentivesClaimingLogic[] memory claimingLogics,
            IERC4626[] memory marketsWithIncentives
        )
    {
        claimingLogics = new IIncentivesClaimingLogic[](_silosWithIncentives.length);
        marketsWithIncentives = new IERC4626[](_silosWithIncentives.length);

        for (uint256 i = 0; i < _silosWithIncentives.length; i++) {
            address silo = address(_silosWithIncentives[i]);
            address hookReceiver = IShareToken(silo).hookReceiver();
            address gauge = address(IGaugeHookReceiver(hookReceiver).configuredGauges(IShareToken(silo)));

            require(address(gauge) != address(0), GaugeIsNotConfigured(silo));

            address claimingLogic = address(SILO_INCENTIVES_CONTROLLER_CL_FACTORY.createIncentivesControllerCL({
                _vaultIncentivesController: _vaultIncentivesController,
                _siloIncentivesController: gauge,
                _externalSalt: _salt
            }));

            claimingLogics[i] = IIncentivesClaimingLogic(claimingLogic);

            marketsWithIncentives[i] = IERC4626(silo);

            emit CreateIncentivesCL(address(_vault), address(silo), address(claimingLogic));
        }
    }

    /// @dev Predicts the address of the Silo Vault.
    /// @param _initialOwner The initial owner of the vault.
    /// @param _initialTimelock The initial timelock of the vault.
    /// @param _asset The asset of the vault.
    /// @param _name The name of the vault.
    /// @param _symbol The symbol of the vault.
    /// @param _externalSalt The salt that is generated by the Silo Vault Deployer.
    /// @return predictedAddress The address of the Silo Vault.
    function _predictSiloVaultAddress(
        address _initialOwner,
        uint256 _initialTimelock,
        address _asset,
        string memory _name,
        string memory _symbol,
        bytes32 _externalSalt
    ) internal view returns (address predictedAddress) {
        uint256 nonce = Nonces(address(SILO_VAULTS_FACTORY)).nonces(address(this));
        bytes32 salt = _siloVaultFactorySaltPreview(_externalSalt, nonce++);

        address predictedIncentivesModuleAddress = Clones.predictDeterministicAddress(
            SILO_VAULTS_FACTORY.VAULT_INCENTIVES_MODULE_IMPLEMENTATION(),
            salt,
            address(SILO_VAULTS_FACTORY)
        );

        predictedAddress = SILO_VAULTS_FACTORY.predictSiloVaultAddress({
            _constructorArgs: abi.encode(
                _initialOwner,
                _initialTimelock,
                address(predictedIncentivesModuleAddress),
                _asset,
                _name,
                _symbol
            ),
            _salt: salt,
            _deployer: address(SILO_VAULTS_FACTORY)
        });
    }

    /// @dev Generates the salt for the Silo Vault deployment.
    /// @param _externalSalt The salt that is generated by the Silo Vault Deployer.
    /// @param _nonce The nonce for the deployment.
    /// @return salt The salt that will be generated by the Silo Vault Factory.
    function _siloVaultFactorySaltPreview(bytes32 _externalSalt, uint256 _nonce) internal view returns (bytes32 salt) {
        salt = keccak256(abi.encodePacked(address(this), _nonce, _externalSalt));
    }
}
