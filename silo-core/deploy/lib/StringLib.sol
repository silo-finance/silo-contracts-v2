// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

library StringLib {
    function split(string memory _input, bytes1 _delimiter) internal pure returns (string[] memory results) {
        uint256 strLength = bytes(_input).length;

        string[] memory tmp = new string[](strLength); // max length
        uint256 resultIndex;

        for (uint256 i; i < strLength; i++) {
            bytes1 c = bytes(_input)[i];

            if (uint8(_delimiter) == uint8(c)) {
                resultIndex++;
            } else {
                tmp[resultIndex] = string.concat(tmp[resultIndex], string(abi.encodePacked(c)));
            }
        }

        results = new string[](resultIndex + 1);

        for (uint256 i; i < results.length; i++) {
            results[i] = tmp[i];
        }
    }

    function toUint256(string memory _str) internal pure returns (uint256 x) {
        uint256 strLength = bytes(_str).length;

        for (uint256 i; i < strLength; i++) {
            uint256 c = uint8(bytes(_str)[strLength - i - 1]);
            x += (c - 48) * 10 ** i;
        }
    }
}
