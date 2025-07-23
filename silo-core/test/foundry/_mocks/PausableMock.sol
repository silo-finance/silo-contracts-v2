// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable2Step, Ownable} from "common/access/Ownable1and2Steps.sol";
import {Pausable} from "openzeppelin5/utils/Pausable.sol";

contract PausableMock is Ownable2Step, Pausable {
    constructor() Ownable(msg.sender) {}

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
