// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Clones} from "openzeppelin5/proxy/Clones.sol";

import {IMetaSilo} from "./interfaces/IMetaSilo.sol";
import {IMetaSiloFactory} from "./interfaces/IMetaSiloFactory.sol";

import {EventsLib} from "./libraries/EventsLib.sol";

import {MetaSilo} from "./MetaSilo.sol";
import {VaultIncentivesModule} from "./incentives/VaultIncentivesModule.sol";
import {SiloIncentivesControllerCL} from "./incentives/claiming-logics/SiloIncentivesControllerCL.sol";

/// @title MetaSiloFactory
/// @dev Forked with gratitude from Morpho Labs.
/// @author Silo Labs
/// @custom:contact security@silo.finance
/// @notice This contract allows to create MetaSilo vaults, and to index them easily.
contract MetaSiloFactory is IMetaSiloFactory {
    /* STORAGE */
    address public immutable VAULT_INCENTIVES_MODULE_IMPLEMENTATION;

    /// @inheritdoc IMetaSiloFactory
    mapping(address => bool) public isMetaSilo;

    /* CONSTRUCTOR */

    constructor() {
        VAULT_INCENTIVES_MODULE_IMPLEMENTATION = address(new VaultIncentivesModule(msg.sender));
    }

    /* EXTERNAL */

    /// @inheritdoc IMetaSiloFactory
    function createMetaSilo(
        address initialOwner,
        uint256 initialTimelock,
        address asset,
        string memory name,
        string memory symbol,
        bytes32 salt
    ) external returns (IMetaSilo metaSilo) {
        VaultIncentivesModule vaultIncentivesModule = VaultIncentivesModule(
            Clones.cloneDeterministic(VAULT_INCENTIVES_MODULE_IMPLEMENTATION, salt)
        );

        metaSilo = IMetaSilo(address(
            new MetaSilo{salt: salt}(initialOwner, initialTimelock, vaultIncentivesModule, asset, name, symbol))
        );

        isMetaSilo[address(metaSilo)] = true;

        emit EventsLib.CreateMetaSilo(
            address(metaSilo), msg.sender, initialOwner, initialTimelock, asset, name, symbol, salt
        );
    }
}
