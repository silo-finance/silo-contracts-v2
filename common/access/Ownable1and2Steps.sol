// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";

/// @dev This contract is a wrapper around Ownable2Step that allows for 1-step ownership transfer
abstract contract Ownable1and2Steps is Ownable2Step {
    constructor(address _initialOwner) Ownable(_initialOwner) {}

    /// @notice Transfer ownership to a new address. Pending ownership transfer will be canceled.
    /// @param newOwner The new owner of the contract
    function transferOwnership1Step(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }

        Ownable2Step._transferOwnership(newOwner);
    }
}
