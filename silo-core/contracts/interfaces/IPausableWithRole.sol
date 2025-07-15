// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/// @title Pausable contract with a separate role for pausing
interface IPausableWithRole {
    function unpause() external;
    function pause() external;
}
