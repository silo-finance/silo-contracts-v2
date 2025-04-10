// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";
import {ISiloVault} from "./ISiloVault.sol";

/// @title IVaultDeployer
/// @dev Forked with gratitude from Morpho Labs.
/// @author Silo Labs
/// @custom:contact security@silo.finance
/// @notice Interface of VaultDeployer.
interface ISiloVaultsDeployer {
    /// @notice Whether a SiloVault vault was created with the factory.
    function isSiloVault(address _target) external view returns (bool);

    /// @notice Whether a IdleVault vault was created with the factory.
    function isIdleVault(address _target) external view returns (bool);

    /// @notice Creates a new SiloVault vault and idle vault for it.
    /// @param _initialOwner The owner of the vault.
    /// @param _initialTimelock The initial timelock of the vault.
    /// @param _asset The address of the underlying asset.
    /// @param _name The name of the vault.
    /// @param _symbol The symbol of the vault.
    function createSiloVaultWithIdle(
        address _initialOwner,
        uint256 _initialTimelock,
        address _asset,
        string memory _name,
        string memory _symbol
    ) external returns (ISiloVault siloVault, IERC4626 idleVault);
}
