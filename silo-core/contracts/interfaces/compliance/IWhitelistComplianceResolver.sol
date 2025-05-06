// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

/// @title IWhitelistComplianceResolver
/// @notice Interface for the whitelist compliance resolver.
/// @dev This is an extension for the compliance resolver.
/// So, some accounts may be white listed and skip the compliance checks.
interface IWhitelistComplianceResolver {
    /// @dev Emitted when an address is added to the whitelist for a specific action
    /// @param action The action for which the address was added to the whitelist
    /// @param account The address that was added to the whitelist
    event AddressAddedToWhitelist(uint256 indexed action, address indexed account);
    /// @dev Emitted when an address is removed from the whitelist for a specific action
    /// @param action The action for which the address was removed from the whitelist
    /// @param account The address that was removed from the whitelist
    event AddressRemovedFromWhitelist(uint256 indexed action, address indexed account);

    /// @dev Revert when trying to add zero address to whitelist
    error EmptyAddress();
    /// @dev Revert when trying to add an address that is already in the whitelist
    error AddressAlreadyWhitelisted();
    /// @dev Revert when trying to remove an address that is not in the whitelist
    error AddressNotWhitelisted();
    /// @dev Revert when passing empty arrays
    error EmptyArrayInput();
    /// @dev Revert when the length of the actions and addresses arrays are not the same
    error InvalidArrayLength();

    /// @notice Add multiple addresses to multiple actions.
    /// @param _actions The actions to add the addresses to the white list for.
    /// @param _addresses The addresses to add.
    function addToWhitelist(uint256[] calldata _actions, address[] calldata _addresses) external;

    /// @notice Remove multiple addresses from multiple actions.
    /// @param _actions The actions to remove the addresses from the white list for.
    /// @param _addresses The addresses to remove.
    function removeFromWhitelist(uint256[] calldata _actions, address[] calldata _addresses) external;

    /// @notice Check if the address is in the white list.
    /// @param _action The action to check if the address is in the white list for.
    /// @param _address The address to check.
    /// @return status True if the address is in the white list.
    function isInWhitelist(uint256 _action, address _address) external view returns (bool status);

    /// @notice Get the white list.
    /// @param _action The action to get the white list for.
    /// @return whitelist The white list.
    function getWhitelist(uint256 _action) external view returns (address[] memory whitelist);
}
