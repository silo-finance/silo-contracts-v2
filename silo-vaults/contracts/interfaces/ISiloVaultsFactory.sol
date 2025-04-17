// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {IIncentivesClaimingLogic} from "silo-vaults/contracts/interfaces/IIncentivesClaimingLogic.sol";
import {IIncentivesClaimingLogicFactory} from "silo-vaults/contracts/interfaces/IIncentivesClaimingLogicFactory.sol";

import {ISiloVault} from "./ISiloVault.sol";

/// @title ISiloVaultsFactory
/// @dev Forked with gratitude from Morpho Labs.
/// @author Silo Labs
/// @custom:contact security@silo.finance
/// @notice Interface of SiloVault's factory.
interface ISiloVaultsFactory {
    function VAULT_INCENTIVES_MODULE_IMPLEMENTATION() external view returns (address);

    /// @notice Whether a SiloVault vault was created with the factory.
    function isSiloVault(address _target) external view returns (bool);

    /// @notice Creates a new SiloVault vault.
    /// @param _initialOwner The owner of the vault.
    /// @param _initialTimelock The initial timelock of the vault.
    /// @param _asset The address of the underlying asset.
    /// @param _name The name of the vault.
    /// @param _symbol The symbol of the vault.
    /// @param _externalSalt The external salt to use for the creation of the SiloVault vault.
    /// @param _notificationReceiver The notification receiver for the vault pre-configuration.
    /// @param _claimingLogics Incentive claiming logics for the vault pre-configuration.
    /// @param _marketsWithIncentives The markets with incentives for the vault pre-configuration.
    /// @param _trustedFactories Trusted factories for the vault pre-configuration.
    function createSiloVault(
        address _initialOwner,
        uint256 _initialTimelock,
        address _asset,
        string memory _name,
        string memory _symbol,
        bytes32 _externalSalt,
        address _notificationReceiver,
        IIncentivesClaimingLogic[] memory _claimingLogics,
        IERC4626[] memory _marketsWithIncentives,
        IIncentivesClaimingLogicFactory[] memory _trustedFactories
    ) external returns (ISiloVault SiloVault);

    /// @dev Predicts the address of the Silo Vault.
    /// @param _constructorArgs The constructor arguments for the Silo Vault encoded via abi.encode.
    /// @param _salt The salt for the deployment.
    /// @param _deployer The deployer of the Silo Vault.
    /// @return vaultAddress The address of the Silo Vault.
    function predictSiloVaultAddress(bytes memory _constructorArgs, bytes32 _salt, address _deployer)
        external
        pure
        returns (address vaultAddress);
}
