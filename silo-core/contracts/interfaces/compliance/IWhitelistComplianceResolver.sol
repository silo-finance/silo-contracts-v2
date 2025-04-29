// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

/// @title IWhitelistComplianceResolver
/// @notice Interface for the whitelist compliance resolver.
/// @dev This is an extension for the compliance resolver.
/// So, some accounts may be white listed and skip the compliance checks.
interface IWhitelistComplianceResolver {
    /// @notice Add the address to the white list for the actions.
    /// @param _actions The actions to add the address to the white list for.
    /// @param _address The address to add.
    function addToWhitelist(uint256[] calldata _actions, address _address) external;

    /// @notice Add the address to the white list for the action.
    /// @param _action The action to add the address to the white list for.
    /// @param _addresses The addresses to add.
    function addToWhitelist(uint256 _action, address[] calldata _addresses) external;

    /// @notice Remove the address from the white list for the actions.
    /// @param _actions The actions to remove the address from the white list for.
    /// @param _address The address to remove.
    function removeFromWhitelist(uint256[] calldata _actions, address _address) external;

    /// @notice Remove the address from the white list for the action.
    /// @param _action The action to remove the address from the white list for.
    /// @param _addresses The addresses to remove.
    function removeFromWhitelist(uint256 _action, address[] calldata _addresses) external;

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
