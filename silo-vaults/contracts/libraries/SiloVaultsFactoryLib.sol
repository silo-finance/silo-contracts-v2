// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Clones} from "openzeppelin5/proxy/Clones.sol";

import {ISiloVault} from "../interfaces/ISiloVault.sol";
import {SiloVault} from "../SiloVault.sol";
import {VaultIncentivesModule} from "../incentives/VaultIncentivesModule.sol";

import {EventsLib} from "./EventsLib.sol";

library SiloVaultsFactoryLib {
    function createSiloVault(
        address _vaultIncentivesImplementation,
        address _initialOwner,
        uint256 _initialTimelock,
        address _asset,
        string memory _name,
        string memory _symbol,
        bytes32 _salt
    ) external returns (ISiloVault siloVault) {
        VaultIncentivesModule vaultIncentivesModule = VaultIncentivesModule(
            Clones.cloneDeterministic(_vaultIncentivesImplementation, _salt)
        );

        siloVault = ISiloVault(address(
            new SiloVault{salt: _salt}(
                _initialOwner, _initialTimelock, vaultIncentivesModule, _asset, _name, _symbol
            ))
        );

        vaultIncentivesModule.__VaultIncentivesModule_init(siloVault);

        emit EventsLib.CreateSiloVault(
            address(siloVault), msg.sender, _initialOwner, _initialTimelock, _asset, _name, _symbol
        );
    }
}
