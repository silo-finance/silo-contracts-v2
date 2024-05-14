// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

contract Creator {
    address private immutable _creator;

    error OnlyCreator();

    modifier onlyCreator() {
        if (msg.sender != _creator) revert OnlyCreator();
        _;
    }

    constructor() {
        _creator = msg.sender;
    }
}
