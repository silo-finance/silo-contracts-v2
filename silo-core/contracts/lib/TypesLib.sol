// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

library TypesLib {
    uint256 constant POSITION_TYPE_UNKNOWN = 0;
    uint256 constant POSITION_TYPE_ONE_TOKEN = 1;
    uint256 constant POSITION_TYPE_TWO_TOKENS = 2;
    uint256 constant POSITION_TYPE_DEPOSIT = 2;

    uint256 constant CONFIG_FOR_BORROW = 1;
    uint256 constant CONFIG_FOR_WITHDRAW = 1;
}
