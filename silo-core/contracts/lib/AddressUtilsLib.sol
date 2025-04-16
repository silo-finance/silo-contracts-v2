// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

library AddressUtilsLib {
    error InvalidAddressString();

    /**
     * @dev Converts a hex string representation of an address to an address type
     * @param _hexString The hex string representation of an address (with or without 0x prefix)
     * @return addr The address type
     */
    function fromHexString(string memory _hexString) internal pure returns (address addr) {
        require(bytes(_hexString).length == 42, InvalidAddressString());

        for (uint256 i = 2; i < 42; i++) {
            (bool success, uint8 value) = tryHexToUint(bytes(_hexString)[i]);

            if (!success) revert InvalidAddressString();

            addr = address(uint160(addr) * 16 + value);
        }
    }

    /**
     * @notice Copied from OZ
     * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/governance/Governor.sol#L803
     * @dev Try to parse a character from a string as a hex value. Returns `(true, value)` if the char is in
     * `[0-9a-fA-F]` and `(false, 0)` otherwise. Value is guaranteed to be in the range `0 <= value < 16`
     */
    function tryHexToUint(bytes1 char) internal pure returns (bool, uint8) {
        uint8 c = uint8(char);
        unchecked {
            // Case 0-9
            if (47 < c && c < 58) {
                return (true, c - 48);
            }
            // Case A-F
            else if (64 < c && c < 71) {
                return (true, c - 55);
            }
            // Case a-f
            else if (96 < c && c < 103) {
                return (true, c - 87);
            }
            // Else: not a hex char
            else {
                return (false, 0);
            }
        }
    }
}
