// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Ownable2StepUpgradeable, OwnableUpgradeable} from "openzeppelin5-upgradeable/access/Ownable2StepUpgradeable.sol";

/// @dev This contract is a wrapper around Ownable2Step that allows for 1-step ownership transfer
abstract contract Ownable1and2StepsUpgradable is Ownable2StepUpgradeable {
    /// @notice Transfer ownership to a new address. Pending ownership transfer will be canceled.
    /// @param newOwner The new owner of the contract
    function transferOwnership1Step(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }

        Ownable2StepUpgradeable._transferOwnership(newOwner);
    }
}
