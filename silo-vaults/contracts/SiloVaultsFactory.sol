// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {ISiloVault} from "./interfaces/ISiloVault.sol";
import {ISiloVaultsFactory} from "./interfaces/ISiloVaultsFactory.sol";

import {EventsLib} from "./libraries/EventsLib.sol";

import {SiloVault} from "./SiloVault.sol";
import {VaultIncentivesModule} from "./incentives/VaultIncentivesModule.sol";

/// @title SiloVaultsFactory
/// @dev Forked with gratitude from Morpho Labs.
/// @author Silo Labs
/// @custom:contact security@silo.finance
/// @notice This contract allows to create SiloVault vaults, and to index them easily.
contract SiloVaultsFactory is ISiloVaultsFactory {
    /// @inheritdoc ISiloVaultsFactory
    mapping(address => bool) public isSiloVault;

    /// @inheritdoc ISiloVaultsFactory
    function createSiloVault(
        address initialOwner,
        uint256 initialTimelock,
        address asset,
        string memory name,
        string memory symbol,
        bytes32 salt
    ) external virtual returns (ISiloVault siloVault) {
        VaultIncentivesModule vaultIncentivesModule = new VaultIncentivesModule{salt: salt}(initialOwner);

        siloVault = ISiloVault(address(
            new SiloVault{salt: salt}(initialOwner, initialTimelock, vaultIncentivesModule, asset, name, symbol))
        );

        isSiloVault[address(siloVault)] = true;

        emit EventsLib.CreateSiloVault(
            address(siloVault), msg.sender, initialOwner, initialTimelock, asset, name, symbol, salt
        );
    }
}
