// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IMetaMorpho} from "./IMetaMorpho.sol";

/// @title IMetaMorphoFactory
/// @dev Forked from Morpho with gratitude
/// @author Silo Labs
/// @custom:contact security@silo.finance
/// @notice Interface of MetaMorpho's factory.
interface IMetaMorphoFactory {
    /// @notice Whether a MetaMorpho vault was created with the factory.
    function isMetaMorpho(address _target) external view returns (bool);

    /// @notice Creates a new MetaMorpho vault.
    /// @param _initialOwner The owner of the vault.
    /// @param _initialTimelock The initial timelock of the vault.
    /// @param _asset The address of the underlying asset.
    /// @param _name The name of the vault.
    /// @param _symbol The symbol of the vault.
    /// @param _salt The salt to use for the MetaMorpho vault's CREATE2 address.
    function createMetaMorpho(
        address _initialOwner,
        uint256 _initialTimelock,
        address _asset,
        string memory _name,
        string memory _symbol,
        bytes32 _salt
    ) external returns (IMetaMorpho metaMorpho);
}
