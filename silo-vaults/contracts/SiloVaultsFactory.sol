// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Clones} from "openzeppelin5/proxy/Clones.sol";
import {IERC4626, IERC20Metadata} from "openzeppelin5/interfaces/IERC4626.sol";

import {Create2Factory} from "common/utils/Create2Factory.sol";
import {ISiloVault} from "./interfaces/ISiloVault.sol";
import {ISiloVaultsFactory} from "./interfaces/ISiloVaultsFactory.sol";

import {SiloVaultsFactoryLib} from "./libraries/SiloVaultsFactoryLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";

import {SiloVault} from "./SiloVault.sol";
import {IdleVault} from "./IdleVault.sol";

import {VaultIncentivesModule} from "./incentives/VaultIncentivesModule.sol";

/// @title SiloVaultsFactory
/// @dev Forked with gratitude from Morpho Labs.
/// @author Silo Labs
/// @custom:contact security@silo.finance
/// @notice This contract allows to create SiloVault vaults, and to index them easily.
contract SiloVaultsFactory is Create2Factory, ISiloVaultsFactory {
    address public immutable VAULT_INCENTIVES_MODULE_IMPLEMENTATION;

    /// @inheritdoc ISiloVaultsFactory
    mapping(address => bool) public isSiloVault;

    /// @inheritdoc ISiloVaultsFactory
    mapping(address => bool) public isIdleVault;

    constructor() {
        VAULT_INCENTIVES_MODULE_IMPLEMENTATION = address(new VaultIncentivesModule());
    }

    function createIdleVault(IERC4626 _vault) public virtual returns (IdleVault idleVault) {
        idleVault = new IdleVault{salt: _salt()}(
            address(_vault),
            _vault.asset(),
            string.concat("IdleVault for ", IERC20Metadata(address(_vault)).name()),
            string.concat("IV-", IERC20Metadata(address(_vault)).symbol())
        );

        isIdleVault[address(idleVault)] = true;

        emit EventsLib.CreateIdleVault(address(idleVault), address(_vault));
    }

    /// @inheritdoc ISiloVaultsFactory
    function createSiloVault(
        address _initialOwner,
        uint256 _initialTimelock,
        address _asset,
        string memory _name,
        string memory _symbol,
        bool _withIdle
    ) external virtual returns (ISiloVault siloVault, IdleVault idleVault) {
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

        if (_withIdle) {
            idleVault = createIdleVault(siloVault);
        }
    }
}
