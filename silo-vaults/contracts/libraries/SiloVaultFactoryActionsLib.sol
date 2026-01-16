// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {Clones} from "openzeppelin5/proxy/Clones.sol";
import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {ISiloVault} from "silo-vaults/contracts/interfaces/ISiloVault.sol";
import {SiloVault} from "silo-vaults/contracts/SiloVault.sol";

/// @title Silo Vault Factory Actions Library
library SiloVaultFactoryActionsLib {
    /// @dev Creates a new Silo Vault.
    /// @param _initialOwner The initial owner of the vault.
    /// @param _initialTimelock The initial timelock of the vault.
    /// @param _asset The asset of the vault.
    /// @param _name The name of the vault.
    /// @param _symbol The symbol of the vault.
    /// @param _salt The salt for the deployment.
    function createSiloVault(
        address _initialOwner,
        uint256 _initialTimelock,
        address _asset,
        string memory _name,
        string memory _symbol,
        bytes32 _salt
    ) external returns (ISiloVault siloVault) {
        siloVault = ISiloVault(address(
            new SiloVault{salt: _salt}(
                _initialOwner, _initialTimelock, _asset, _name, _symbol
            )
        ));
    }

    /// @param _constructorArgs The constructor arguments for the Silo Vault encoded via abi.encode.
    /// @return codeHash The init code hash of the Silo Vault.
    function initCodeHash(bytes memory _constructorArgs)
        external
        pure
        returns (bytes32 codeHash)
    {
        codeHash = keccak256(abi.encodePacked(type(SiloVault).creationCode, _constructorArgs));
    }
}
