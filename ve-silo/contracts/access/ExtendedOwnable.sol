// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";

import {Manageable} from "./Manageable.sol";

contract ExtendedOwnable is Ownable2Step, Manageable {
    constructor() Manageable(_msgSender()) Ownable(_msgSender()) {}

    /// @dev Returns the address of the current owner.
    function owner() public view override(Ownable, Manageable) virtual returns (address) {
        return Ownable.owner();
    }
}
