// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IGlobalPause {
    struct ContractPauseStatus {
        address contractAddress;
        bool isPaused;
    }

    event Paused(address _contract);
    event Unpaused(address _contract);
    event OwnershipAccepted(address _contract);
    event ContractAdded(address _contract);
    event ContractRemoved(address _contract);
    event Authorized(address _account);
    event Unauthorized(address _account);
    event FailedToPause(address _contract);
    event FailedToUnpause(address _contract);

    error Forbidden();
    error ContractsNotEmpty();
    error AuthorizedToPauseNotEmpty();
    error FailedToAdd();
    error FailedToRemove();

    /// @notice Pause all contracts
    function pauseAll() external;

    /// @notice Unpause all contracts
    function unpauseAll() external;

    /// @notice Add a contract to the list of contracts to pause and unpause
    /// @param _contract The contract to add
    function addContract(address _contract) external;

    /// @notice Remove a contract from the list of contracts to pause and unpause
    /// @param _contract The contract to remove
    function removeContract(address _contract) external;

    /// @notice Grant authorization to an account to pause and unpause contracts
    /// @param _account The account to grant authorization to
    function grantAuthorization(address _account) external;

    /// @notice Revoke authorization from an account to pause and unpause contracts
    /// @param _account The account to revoke authorization from
    function revokeAuthorization(address _account) external;

    /// @notice Pause a contract
    /// @param _contract The contract to pause
    function pause(address _contract) external;

    /// @notice Unpause a contract
    /// @param _contract The contract to unpause
    function unpause(address _contract) external;

    /// @notice Transfer ownership of a contract
    /// @param _contract The contract to transfer ownership of
    /// @param _newOwner The new owner of the contract
    function transferOwnershipFrom(address _contract, address _newOwner) external;

    /// @notice Accept ownership of a contract
    /// @param _contract The contract to accept ownership of
    function acceptOwnership(address _contract) external;

    /// @notice Get all contracts
    /// @return _contracts The list of contracts
    function allContracts() external view returns (address[] memory);

    /// @notice Get all authorized accounts to pause and unpause contracts
    /// @return _authorizedToPause The list of authorized accounts
    function authorizedToPause() external view returns (address[] memory);

    /// @notice Check if an account is a signer of the multisig contract
    /// @param _account The account to check
    /// @return result True if the account is a signer, false otherwise
    function isSigner(address _account) external view returns (bool result);

    /// @notice Get the pause status of all contracts
    /// @return result The list of contracts and their pause statuses
    function getAllContractsPauseStatus() external view returns (ContractPauseStatus[] memory result);
}
