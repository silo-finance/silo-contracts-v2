// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

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
    function createSiloVault(
        address _initialOwner,
        uint256 _initialTimelock,
        address _asset,
        string memory _name,
        string memory _symbol,
        bytes32 _externalSalt
    ) external returns (ISiloVault SiloVault);

    /// @notice Predicts the address of a SiloVault vault.
    /// @param _constructorArgs The constructor arguments of the SiloVault vault.
    /// @param _saltVault The salt to use for the creation of the SiloVault vault.
    function predictSiloVaultAddress(
        bytes memory _constructorArgs,
        bytes32 _saltVault
    ) external view returns (address predictedAddress);
}
