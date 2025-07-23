// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IGnosisSafeLike} from "common/utils/interfaces/IGnosisSafeLike.sol";

contract GnosisSafeMock is IGnosisSafeLike {
    address[] private _owners;

    constructor(address[] memory owners) {
        _owners = owners;
    }

    function getOwners() external view returns (address[] memory) {
        return _owners;
    }

    function addOwner(address owner) external {
        _owners.push(owner);
    }

    function removeOwner(address owner) external {
        uint256 length = _owners.length;
        for (uint256 i = 0; i < length; i++) {
            if (_owners[i] == owner) {
                _owners[i] = _owners[length - 1];
                _owners.pop();
                break;
            }
        }
    }
}
