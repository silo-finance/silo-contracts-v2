// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

library ComputeAddrLib {
    function computeAddress(address deployer, uint256 nonce) public pure returns (address) {
        bytes memory data;

        if (nonce == 0x00) {
            data = abi.encodePacked(
                bytes1(0xd6),
                bytes1(0x94),
                deployer,
                bytes1(0x80)
            );
        } else if (nonce <= 0x7f) {
            data = abi.encodePacked(
                bytes1(0xd6),
                bytes1(0x94),
                deployer,
                uint8(nonce)
            );
        } else if (nonce <= 0xff) {
            data = abi.encodePacked(
                bytes1(0xd7),
                bytes1(0x94),
                deployer,
                bytes1(0x81),
                uint8(nonce)
            );
        } else if (nonce <= 0xffff) {
            data = abi.encodePacked(
                bytes1(0xd8),
                bytes1(0x94),
                deployer,
                bytes1(0x82),
                uint16(nonce)
            );
        } else if (nonce <= 0xffffff) {
            data = abi.encodePacked(
                bytes1(0xd9),
                bytes1(0x94),
                deployer,
                bytes1(0x83),
                uint24(nonce)
            );
        } else {
            data = abi.encodePacked(
                bytes1(0xda),
                bytes1(0x94),
                deployer,
                bytes1(0x84),
                uint32(nonce)
            );
        }

        bytes32 hash = keccak256(data);
        return address(uint160(uint256(hash)));
    }
}
