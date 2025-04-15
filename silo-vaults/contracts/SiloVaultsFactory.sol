// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Create2} from "openzeppelin5/utils/Create2.sol";

import {Create2Factory} from "common/utils/Create2Factory.sol";
import {ISiloVault} from "./interfaces/ISiloVault.sol";
import {ISiloVaultsFactory} from "./interfaces/ISiloVaultsFactory.sol";

import {EventsLib} from "./libraries/EventsLib.sol";
import {SiloVaultFactoryActionsLib} from "./libraries/SiloVaultFactoryActionsLib.sol";

import {VaultIncentivesModule} from "./incentives/VaultIncentivesModule.sol";

/// @title SiloVaultsFactory
/// @dev Forked with gratitude from Morpho Labs.
/// @author Silo Labs
/// @custom:contact security@silo.finance
/// @notice This contract allows to create SiloVault vaults, and to index them easily.
contract SiloVaultsFactory is Create2Factory, ISiloVaultsFactory {
    /* STORAGE */
    address public immutable VAULT_INCENTIVES_MODULE_IMPLEMENTATION;

    /// @inheritdoc ISiloVaultsFactory
    mapping(address => bool) public isSiloVault;

    /* CONSTRUCTOR */

    constructor() {
        VAULT_INCENTIVES_MODULE_IMPLEMENTATION = address(new VaultIncentivesModule());
    }

    /* EXTERNAL */

    /// @inheritdoc ISiloVaultsFactory
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
    ) external virtual returns (ISiloVault siloVault) {
        siloVault = SiloVaultFactoryActionsLib.createSiloVault({
            _initialOwner: _initialOwner,
            _initialTimelock: _initialTimelock,
            _asset: _asset,
            _name: _name,
            _symbol: _symbol,
            _salt: _salt(_externalSalt),
            _notificationReceiver: _notificationReceiver,
            _incentivesModuleImplementation: VAULT_INCENTIVES_MODULE_IMPLEMENTATION,
            _claimingLogics: _claimingLogics,
            _marketsWithIncentives: _marketsWithIncentives
        });

        isSiloVault[address(siloVault)] = true;

        emit EventsLib.CreateSiloVault(
            address(siloVault), msg.sender, _initialOwner, _initialTimelock, _asset, _name, _symbol
        );
    }
}
