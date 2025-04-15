// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {Clones} from "openzeppelin5/proxy/Clones.sol";
import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {IIncentivesClaimingLogic} from "silo-vaults/contracts/interfaces/IIncentivesClaimingLogic.sol";
import {ISiloVault} from "silo-vaults/contracts/interfaces/ISiloVault.sol";
import {SiloVault} from "silo-vaults/contracts/SiloVault.sol";
import {VaultIncentivesModule} from "silo-vaults/contracts/incentives/VaultIncentivesModule.sol";

library SiloVaultFactoryActionsLib {
    function createSiloVault(
        address _initialOwner,
        uint256 _initialTimelock,
        address _asset,
        string memory _name,
        string memory _symbol,
        bytes32 _salt,
        address _notificationReceiver,
        address _incentivesModuleImplementation,
        IIncentivesClaimingLogic[] memory _claimingLogics,
        IERC4626[] memory _marketsWithIncentives
    ) external returns (ISiloVault siloVault) {
        VaultIncentivesModule vaultIncentivesModule = VaultIncentivesModule(
            Clones.cloneDeterministic(_incentivesModuleImplementation, _salt)
        );

        siloVault = ISiloVault(address(
            new SiloVault{salt: _salt}(
                _initialOwner, _initialTimelock, vaultIncentivesModule, _asset, _name, _symbol
            )
        ));

        vaultIncentivesModule.__VaultIncentivesModule_init(
            siloVault,
            _notificationReceiver,
            _claimingLogics,
            _marketsWithIncentives
        );
    }

    function predictSiloVaultAddress(bytes memory _constructorArgs, bytes32 _salt, address _deployer)
        external
        pure
        returns (address vaultAddress)
    {
        bytes32 initCodeHash = keccak256(abi.encodePacked(type(SiloVault).creationCode, _constructorArgs));

         vaultAddress = address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            _deployer,
            _salt,
            initCodeHash
        )))));
    }
}
