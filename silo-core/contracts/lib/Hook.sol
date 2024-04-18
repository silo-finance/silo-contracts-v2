// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// solhint-disable private-vars-leading-underscore
library Hook {
    uint256 internal constant RETURN_CODE_SUCCESS = 0;
    uint256 internal constant RETURN_CODE_REQUEST_TO_REVERT_TX = 1;

    uint256 internal constant NONE = 0;
    uint256 internal constant SAME_ASSET = 2 ** 1;
    uint256 internal constant TWO_ASSETS = 2 ** 2;
    uint256 internal constant BEFORE = 2 ** 3;
    uint256 internal constant AFTER = 2 ** 4;
    uint256 internal constant DEPOSIT = 2 ** 5;
    uint256 internal constant BORROW = 2 ** 6;
    uint256 internal constant REPAY = 2 ** 7;
    uint256 internal constant WITHDRAW = 2 ** 8;
    uint256 internal constant SHARE_TRANSFER = 2 ** 9;
    uint256 internal constant TRANSITION_COLLATERAL = 2 ** 10;
    uint256 internal constant SWITCH_COLLATERAL = 2 ** 11;
    uint256 internal constant LEVERAGE = 2 ** 12;
    uint256 internal constant LIQUIDATION = 2 ** 13;

    uint256 internal constant BEFORE_DEPOSIT = 2 ** 3 | 2 ** 5;
    uint256 internal constant AFTER_DEPOSIT = 2 ** 4 | 2 ** 5;
    uint256 internal constant BORROW_SAME_ASSET = 2 ** 6 | 2 ** 1;
    uint256 internal constant BORROW_TWO_ASSETS = 2 ** 6 | 2 ** 2;
    uint256 internal constant BEFORE_REPAY = 2 ** 3 | 2 ** 7;
    uint256 internal constant AFTER_REPAY = 2 ** 4 | 2 ** 7;
    uint256 internal constant BEFORE_WITHDRAW = 2 ** 3 | 2 ** 8;
    uint256 internal constant AFTER_WITHDRAW = 2 ** 4 | 2 ** 8;
    uint256 internal constant BEFORE_LIQUIDATION = 2 ** 3 | 2 ** 9;
    uint256 internal constant AFTER_LIQUIDATION = 2 ** 4 | 2 ** 9;

    uint256 internal constant BEFORE_SHARE_TRANSFER = 2 ** 3 | 2 ** 10;
    uint256 internal constant AFTER_SHARE_TRANSFER = 2 ** 4 | 2 ** 10;

    uint256 internal constant BEFORE_TRANSITION_COLLATERAL = 2 ** 3 | 2 ** 11;
    uint256 internal constant AFTER_TRANSITION_COLLATERAL = 2 ** 4 | 2 ** 11;

    uint256 internal constant BEFORE_SWITCH_COLLATERAL = 2 ** 3 | 2 ** 12;
    uint256 internal constant AFTER_SWITCH_COLLATERAL = 2 ** 4 | 2 ** 12;
}
