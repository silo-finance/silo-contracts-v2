// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloVault} from "silo-vaults/contracts/interfaces/ISiloVault.sol";

/// @title ISiloVaultDeployer
/// @dev Deploys Silo Vault,Idle Vault
interface ISiloVaultDeployer {
    struct CreateSiloVaultParams {
        address initialOwner; // initial owner of the vault
        uint256 initialTimelock; // initial timelock of the vault
        address asset; // asset of the vault
        string name; // name of the vault
        string symbol; // symbol of the vault
    }

    error EmptySiloVaultFactory();
    error EmptyIdleVaultFactory();
    error VaultAddressMismatch();
    error GaugeIsNotConfigured(address silo);

    /// @notice Emitted when a new Silo Vault is created.
    /// @param vault The address of the deployed Silo Vault.
    /// @param idleVault The address of the deployed Idle Vault.
    event CreateSiloVault(address indexed vault, address idleVault);

    /// @notice Create a new Silo Vault
    /// @param params The parameters for the Silo Vault deployment.
    /// @return vault The deployed Silo Vault.
    /// @return idleVault The deployed Idle Vault.
    function createSiloVault(CreateSiloVaultParams memory params) external returns (
        ISiloVault vault,
        IERC4626 idleVault
    );
}
