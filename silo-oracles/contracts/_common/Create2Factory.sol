// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.6;

import {Nonces} from "./Nonces.sol";

contract Create2Factory is Nonces {
    function _salt() internal returns (bytes32 salt) {
        salt = keccak256(abi.encodePacked(
            msg.sender,
            _useNonce(msg.sender)
        ));
    }

    function _salt(bytes32 _externalSalt) internal returns (bytes32 salt) {
        salt = keccak256(abi.encodePacked(
            msg.sender,
            _useNonce(msg.sender),
            _externalSalt
        ));
    }
}
