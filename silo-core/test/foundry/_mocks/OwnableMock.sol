// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable} from "common/access/Ownable.sol";

/// @title OwnableMock
/// @notice Mock implementation of the abstract Ownable contract for testing
contract OwnableMock is Ownable {
    constructor(address _initialOwner) Ownable(_initialOwner) {}
}