// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface ICrossReentrancyGuard {
    error CrossReentrantCall();
    error CrossReentrancyNotActive();

    /// @notice only silo method for cross Silo reentrancy
    function turnOnReentrancyProtection() external;

    /// @notice only silo method for cross Silo reentrancy
    function turnOffReentrancyProtection() external;

    /// @notice view method for checking cross Silo reentrancy flag
    /// @return entered true if the reentrancy guard is currently set to "entered", which indicates there is a
    /// `nonReentrant` function in the call stack.
    function reentrancyGuardEntered() external view returns (bool entered);
}