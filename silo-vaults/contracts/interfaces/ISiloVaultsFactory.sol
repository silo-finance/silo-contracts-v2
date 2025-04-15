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
    /// @param _notificationReceiver The notification receiver for the vault pre-configuration.
    /// @param _claimingLogics Incentive claiming logics for the vault pre-configuration.
    /// @param _marketsWithIncentives The markets with incentives for the vault pre-configuration.
    function createSiloVault(
        address _initialOwner,
        uint256 _initialTimelock,
        address _asset,
        string memory _name,
        string memory _symbol,
        bytes32 _externalSalt,
        address _notificationReceiver,
        address[] memory _claimingLogics,
        address[] memory _marketsWithIncentives
    ) external returns (ISiloVault SiloVault);
}
