// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {Clones} from "openzeppelin5/proxy/Clones.sol";
import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {IIncentivesClaimingLogic} from "silo-vaults/contracts/interfaces/IIncentivesClaimingLogic.sol";
import {IIncentivesClaimingLogicFactory} from "silo-vaults/contracts/interfaces/IIncentivesClaimingLogicFactory.sol";
import {ISiloVault} from "silo-vaults/contracts/interfaces/ISiloVault.sol";
import {SiloVault} from "silo-vaults/contracts/SiloVault.sol";
import {VaultIncentivesModule} from "silo-vaults/contracts/incentives/VaultIncentivesModule.sol";

/// @title Silo Vault Factory Actions Library
library SiloVaultFactoryActionsLib {
    /// @dev Creates a new Silo Vault.
    /// @param _initialOwner The initial owner of the vault.
    /// @param _initialTimelock The initial timelock of the vault.
    /// @param _asset The asset of the vault.
    /// @param _name The name of the vault.
    /// @param _symbol The symbol of the vault.
    /// @param _salt The salt for the deployment.
    /// @param _notificationReceiver The notification receiver for the vault pre-configuration.
    /// @param _incentivesModuleImplementation The implementation of the vault incentives module.
    /// @param _claimingLogics The claiming logics for the vault pre-configuration.
    /// @param _marketsWithIncentives The markets with incentives for the vault pre-configuration.
    /// @param _trustedFactories The trusted factories for the vault pre-configuration.
    function createSiloVault(
        address _initialOwner,
        uint256 _initialTimelock,
        address _asset,
        string memory _name,
        string memory _symbol,
        bytes32 _salt,
        address _notificationReceiver,
        address _incentivesModuleImplementation,
        IIncentivesClaimingLogic[] memory _claimingLogics,
        IERC4626[] memory _marketsWithIncentives,
        IIncentivesClaimingLogicFactory[] memory _trustedFactories
    ) external returns (ISiloVault siloVault) {
        VaultIncentivesModule vaultIncentivesModule = VaultIncentivesModule(
            Clones.cloneDeterministic(_incentivesModuleImplementation, _salt)
        );

        siloVault = ISiloVault(address(
            new SiloVault{salt: _salt}(
                _initialOwner, _initialTimelock, vaultIncentivesModule, _asset, _name, _symbol
            )
        ));

        vaultIncentivesModule.__VaultIncentivesModule_init({
            _vault: siloVault,
            _notificationReceiver: _notificationReceiver,
            _initialClaimingLogics: _claimingLogics,
            _initialMarketsWithIncentives: _marketsWithIncentives,
            _initialTrustedFactories: _trustedFactories
        });
    }

    /// @param _constructorArgs The constructor arguments for the Silo Vault encoded via abi.encode.
    /// @return initCodeHash The init code hash of the Silo Vault.
    function initCodeHash(bytes memory _constructorArgs)
        external
        pure
        returns (bytes32 initCodeHash)
    {
        initCodeHash = keccak256(abi.encodePacked(type(SiloVault).creationCode, _constructorArgs));
    }
}
