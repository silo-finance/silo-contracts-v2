// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Clones} from "openzeppelin5/proxy/Clones.sol";

import {IMetaMorpho} from "./interfaces/IMetaMorpho.sol";
import {IMetaMorphoFactory} from "./interfaces/IMetaMorphoFactory.sol";

import {EventsLib} from "./libraries/EventsLib.sol";

import {MetaMorpho} from "./MetaMorpho.sol";
import {VaultIncentivesModule} from "./incentives/VaultIncentivesModule.sol";

/// @title MetaMorphoFactory
/// @author Morpho Labs
/// @custom:modified Silo Labs
/// @custom:contact security@silo.finance
/// @notice This contract allows to create MetaMorpho vaults, and to index them easily.
contract MetaMorphoFactory is IMetaMorphoFactory {
    /* STORAGE */
    address public immutable VAULT_INCENTIVES_MODULE_IMPLEMENTATION;

    /// @inheritdoc IMetaMorphoFactory
    mapping(address => bool) public isMetaMorpho;

    /* CONSTRUCTOR */

    constructor() {
        VAULT_INCENTIVES_MODULE_IMPLEMENTATION = address(new VaultIncentivesModule(msg.sender));
    }

    /* EXTERNAL */

    /// @inheritdoc IMetaMorphoFactory
    function createMetaMorpho(
        address initialOwner,
        uint256 initialTimelock,
        address asset,
        string memory name,
        string memory symbol,
        bytes32 salt
    ) external returns (IMetaMorpho metaMorpho) {
        VaultIncentivesModule vaultIncentivesModule = VaultIncentivesModule(
            Clones.cloneDeterministic(VAULT_INCENTIVES_MODULE_IMPLEMENTATION, salt)
        );

        metaMorpho = IMetaMorpho(address(
            new MetaMorpho{salt: salt}(initialOwner, initialTimelock, vaultIncentivesModule, asset, name, symbol))
        );

        isMetaMorpho[address(metaMorpho)] = true;

        emit EventsLib.CreateMetaMorpho(
            address(metaMorpho), msg.sender, initialOwner, initialTimelock, asset, name, symbol, salt
        );
    }
}
