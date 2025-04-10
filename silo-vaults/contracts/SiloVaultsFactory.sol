// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Clones} from "openzeppelin5/proxy/Clones.sol";

import {Create2Factory} from "common/utils/Create2Factory.sol";
import {ISiloVault} from "./interfaces/ISiloVault.sol";
import {ISiloVaultsFactory} from "./interfaces/ISiloVaultsFactory.sol";

import {SiloVaultsFactoryLib} from "./libraries/SiloVaultsFactoryLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";

import {SiloVault} from "./SiloVault.sol";
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
        string memory _symbol
    ) external virtual returns (ISiloVault siloVault) {
        siloVault = SiloVaultsFactoryLib.createSiloVault(
            VAULT_INCENTIVES_MODULE_IMPLEMENTATION,
            _initialOwner,
            _initialTimelock,
             _asset,
            _name,
            _symbol,
            _salt()
        );

        isSiloVault[address(siloVault)] = true;
    }
}
