// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable1and2Steps} from "common/access/Ownable1and2Steps.sol";

/// @title OwnableMock
/// @notice Mock implementation of the abstract Ownable1and2Steps contract for testing
contract OwnableMock is Ownable1and2Steps {
    constructor(address _initialOwner) Ownable1and2Steps(_initialOwner) {}
}
