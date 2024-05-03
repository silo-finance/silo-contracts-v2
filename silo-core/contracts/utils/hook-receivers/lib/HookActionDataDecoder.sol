// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

library HookActionDataDecoder {
    uint256 constant PACKED_ADDRESS_LENGTH = 20;
    uint256 constant PACKED_FULL_LENGTH = 32;

    function afterTokenTransferDecode(bytes memory packed)
        internal
        pure
        returns (
            address sender,
            address recipient,
            uint256 amount,
            uint256 senderBalance,
            uint256 recipientBalance,
            uint256 totalSupply
        )
    {
        assembly {
            let pointer := PACKED_ADDRESS_LENGTH
            sender := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            recipient := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            amount := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            senderBalance := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            recipientBalance := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            totalSupply := mload(add(packed, pointer))
        }
    }
}
