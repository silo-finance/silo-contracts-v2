// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {IWhitelistComplianceResolver} from "silo-core/contracts/interfaces/compliance/IWhitelistComplianceResolver.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {EnumerableSet} from "openzeppelin5/utils/structs/EnumerableSet.sol";

/// @title WhitelistComplianceResolver
/// @notice Implementation of whitelist compliance resolver.
/// @dev This contract allows adding addresses to whitelist for specific actions.
/// Whitelisted addresses can skip compliance checks for the specified actions.
contract WhitelistComplianceResolver is IWhitelistComplianceResolver, Ownable2Step {
    using EnumerableSet for EnumerableSet.AddressSet;
    
    /// @dev Mapping from action to set of whitelisted addresses
    mapping(uint256 => EnumerableSet.AddressSet) private _whitelistedAddresses;

    /// @dev Constructor sets the owner
    constructor() Ownable(msg.sender) {}

    /// @inheritdoc IWhitelistComplianceResolver
    function addToWhitelist(uint256[] calldata _actions, address[] calldata _addresses) external onlyOwner {
        require(_actions.length != 0, EmptyArrayInput());
        require(_addresses.length != 0, EmptyArrayInput());
        require(_actions.length == _addresses.length, InvalidArrayLength());

        for (uint256 i = 0; i < _actions.length; i++) {
            _addToWhitelist(_actions[i], _addresses[i]);
        }
    }

    /// @inheritdoc IWhitelistComplianceResolver
    function removeFromWhitelist(uint256[] calldata _actions, address[] calldata _addresses) external onlyOwner {
        require(_actions.length != 0, EmptyArrayInput());
        require(_addresses.length != 0, EmptyArrayInput());
        require(_actions.length == _addresses.length, InvalidArrayLength());

        for (uint256 i = 0; i < _actions.length; i++) {
            _removeFromWhitelist(_actions[i], _addresses[i]);
        }
    }

    /// @inheritdoc IWhitelistComplianceResolver
    function isInWhitelist(uint256 _action, address _addr) external view returns (bool status) {
        return _whitelistedAddresses[_action].contains(_addr);
    }

    /// @inheritdoc IWhitelistComplianceResolver
    function getWhitelist(uint256 _action) external view returns (address[] memory whitelist) {
        return _whitelistedAddresses[_action].values();
    }

    /// @dev Internal function to add an address to the whitelist for a specific action
    /// @param _action The action to add the address to the whitelist for
    /// @param _addr The address to add
    function _addToWhitelist(uint256 _action, address _addr) internal {
        require(_addr != address(0), EmptyAddress());

        bool added = _whitelistedAddresses[_action].add(_addr);

        require(added, AddressAlreadyWhitelisted());

        emit AddressAddedToWhitelist(_action, _addr);
    }

    /// @dev Internal function to remove an address from the whitelist for a specific action
    /// @param _action The action to remove the address from the whitelist for
    /// @param _addr The address to remove
    function _removeFromWhitelist(uint256 _action, address _addr) internal {
        bool removed = _whitelistedAddresses[_action].remove(_addr);

        require(removed, AddressNotWhitelisted());

        emit AddressRemovedFromWhitelist(_action, _addr);
    }
}
