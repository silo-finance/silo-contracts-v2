// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Nonces} from "openzeppelin5/utils/Nonces.sol";

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
