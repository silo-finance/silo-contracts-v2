// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Clones} from "openzeppelin5/proxy/Clones.sol";
import {Create2} from "openzeppelin5/utils/Create2.sol";

import {Create2Factory} from "common/utils/Create2Factory.sol";
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
        address initialOwner,
        uint256 initialTimelock,
        address asset,
        string memory name,
        string memory symbol,
        bytes32 externalSalt
    ) external virtual returns (ISiloVault siloVault) {
        VaultIncentivesModule vaultIncentivesModule = VaultIncentivesModule(
            Clones.cloneDeterministic(VAULT_INCENTIVES_MODULE_IMPLEMENTATION, _salt(externalSalt))
        );

        siloVault = ISiloVault(address(
            new SiloVault{salt: _salt(externalSalt)}(
                initialOwner, initialTimelock, vaultIncentivesModule, asset, name, symbol
            )
        ));

        vaultIncentivesModule.__VaultIncentivesModule_init(siloVault);

        isSiloVault[address(siloVault)] = true;

        emit EventsLib.CreateSiloVault(
            address(siloVault), msg.sender, initialOwner, initialTimelock, asset, name, symbol
        );
    }

    /// @inheritdoc ISiloVaultsFactory
    function predictSiloVaultAddress(
        bytes memory _constructorArgs,
        bytes32 _saltVault
    ) external view returns (address predictedAddress) {
        predictedAddress = _calculateCreate2Address({
            _factory: address(this),
            _salt: _saltVault,
            _initCodeHash: keccak256(abi.encodePacked(
                type(SiloVault).creationCode,
                _constructorArgs
            ))
        });
    }
}
