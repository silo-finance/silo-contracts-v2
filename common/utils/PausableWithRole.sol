// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Pausable} from "openzeppelin5/utils/Pausable.sol";
import {Ownable1and2Steps} from "common/access/Ownable1and2Steps.sol";

/// @title Pausable contract with a separate role for pausing
abstract contract PausableWithRole is Pausable, Ownable1and2Steps {
    /// @notice The addresses that can pause the contract
    mapping(address pauser => bool isPauser) public isPauser;

    /// @notice Emitted when the pause role is granted
    event PauseRoleGranted(address indexed account);

    /// @notice Emitted when the pause role is revoked
    event PauseRoleRevoked(address indexed account);

    /// @dev Revert when the pauser is the zero address
    error PauserEmptyAddress();

    /// @dev Revert when the caller is not the pauser
    error OnlyPauseRole();

    /// @dev Revert when the address is the zero address
    error EmptyAddress();

    /// @dev Revert when the pauser is already granted
    error AlreadyPauser();

    modifier onlyPauseRole() {
        require(isPauser[msg.sender] || msg.sender == owner(), OnlyPauseRole());
        _;
    }

    constructor(address _initialPauser) {
        require(_initialPauser != address(0), PauserEmptyAddress());

        isPauser[_initialPauser] = true;
    }

    function grantPauseRole(address _account) external onlyOwner {
        require(_account != address(0), EmptyAddress());
        require(!isPauser[_account], AlreadyPauser());

        isPauser[_account] = true;
        emit PauseRoleGranted(_account);
    }

    function revokePauseRole(address _account) external onlyOwner {
        require(_account != address(0), EmptyAddress());

        isPauser[_account] = false;
        emit PauseRoleRevoked(_account);
    }

    function pause() external onlyPauseRole {
        _pause();
    }

    function unpause() external onlyPauseRole {
        _unpause();
    }
}
