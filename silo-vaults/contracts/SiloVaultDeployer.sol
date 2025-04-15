// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Nonces} from "openzeppelin5/utils/Nonces.sol";
import {Clones} from "openzeppelin5/proxy/Clones.sol";
import {Create2Factory} from "common/utils/Create2Factory.sol";

import {ISiloVault} from "silo-vaults/contracts/interfaces/ISiloVault.sol";
import {IIncentivesClaimingLogic} from "silo-vaults/contracts/interfaces/IIncentivesClaimingLogic.sol";
import {ISiloVaultsFactory} from "silo-vaults/contracts/interfaces/ISiloVaultsFactory.sol";
import {IdleVaultsFactory} from "silo-vaults/contracts/IdleVaultsFactory.sol";

import {
    ISiloIncentivesControllerFactory
} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesControllerFactory.sol";

import {
    ISiloIncentivesControllerCLFactory
} from "silo-vaults/contracts/interfaces/ISiloIncentivesControllerCLFactory.sol";

import {ISiloIncentivesController} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";
import {ISiloVaultDeployer} from "silo-vaults/contracts/interfaces/ISiloVaultDeployer.sol";

import {console2} from "forge-std/console2.sol";

/// @title SiloVaultDeployer
contract SiloVaultDeployer is ISiloVaultDeployer, Create2Factory {
    ISiloVaultsFactory public immutable SILO_VAULTS_FACTORY;
    ISiloIncentivesControllerFactory public immutable SILO_INCENTIVES_CONTROLLER_FACTORY;
    ISiloIncentivesControllerCLFactory public immutable SILO_INCENTIVES_CONTROLLER_CL_FACTORY;
    IdleVaultsFactory public immutable IDLE_VAULTS_FACTORY;

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

    function createSiloVault(
        address _initialOwner,
        uint256 _initialTimelock,
        address _asset,
        string memory _name,
        string memory _symbol
    ) external returns (
        ISiloVault vault,
        ISiloIncentivesController incentivesController
    ) {
        bytes32 salt = _salt();

        address predictedAddress = _predictSiloVaultAddress({
            _initialOwner: _initialOwner,
            _initialTimelock: _initialTimelock,
            _asset: _asset,
            _name: _name,
            _symbol: _symbol,
            _externalSalt: salt
        });

        incentivesController = ISiloIncentivesController(SILO_INCENTIVES_CONTROLLER_FACTORY.create({
            _owner: _initialOwner,
            _notifier: predictedAddress,
            _externalSalt: salt
        }));

        vault = SILO_VAULTS_FACTORY.createSiloVault({
            _initialOwner: _initialOwner,
            _initialTimelock: _initialTimelock,
            _asset: _asset,
            _name: _name,
            _symbol: _symbol,
            _externalSalt: salt
        });

        require(address(vault) == predictedAddress, VaultAddressMismatch());
    }

    function _predictSiloVaultAddress(
        address _initialOwner,
        uint256 _initialTimelock,
        address _asset,
        string memory _name,
        string memory _symbol,
        bytes32 _externalSalt
    ) internal view returns (address predictedAddress) {
        uint256 nonce = Nonces(address(SILO_VAULTS_FACTORY)).nonces(address(this));
        bytes32 incentivesModuleSalt = _siloVaultFactorySaltPreview(_externalSalt, nonce++);
        bytes32 vaultSalt = _siloVaultFactorySaltPreview(_externalSalt, nonce++);

        address predictedIncentivesModuleAddress = Clones.predictDeterministicAddress(
            SILO_VAULTS_FACTORY.VAULT_INCENTIVES_MODULE_IMPLEMENTATION(),
            incentivesModuleSalt,
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
            _saltVault: vaultSalt
        });
    }


    function _siloVaultFactorySaltPreview(bytes32 _externalSalt, uint256 _nonce) internal view returns (bytes32 salt) {
        salt = keccak256(abi.encodePacked(address(this), _nonce, _externalSalt));
    }
}
