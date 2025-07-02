// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Ownable2Step, Ownable as Ownable1Step} from "openzeppelin5/access/Ownable2Step.sol";

/// @dev This contract is a wrapper around Ownable2Step that allows for 1-step ownership transfer
contract Ownable is Ownable2Step {
    constructor(address _initialOwner) Ownable1Step(_initialOwner) {}

    /// @notice Transfer ownership to a new address
    /// @param newOwner The new owner of the contract
    function transferOwnership1Step(address newOwner) public virtual onlyOwner {
        Ownable2Step._transferOwnership(newOwner);
    }
}
