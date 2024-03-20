// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

library TypesLib {
    uint256 constant POSITION_TYPE_UNKNOWN = 0; // ??
    uint256 constant POSITION_TYPE_ONE_TOKEN = 1;
    uint256 constant POSITION_TYPE_TWO_TOKENS = 0;

    function eq(uint256 _type, uint256 _check) internal pure returns (bool) {
        return _type == _check;
    }
}
