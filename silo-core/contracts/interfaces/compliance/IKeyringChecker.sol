// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

/// @title IKeyringChecker
/// @dev Interface for the Keyring contract to check credentials.
interface IKeyringChecker {
    /// @notice Checks the credential of an entity against a specific policy.
    /// @param policyId The ID of the policy to check against.
    /// @param entity The address of the entity to check.
    /// @return A boolean value indicating whether the entity's credentials pass the policy check.
    function checkCredential(uint256 policyId, address entity) external view returns (bool);
}
