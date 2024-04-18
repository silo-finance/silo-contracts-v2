// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// solhint-disable private-vars-leading-underscore
library Hook {
    uint256 internal constant RETURN_CODE_SUCCESS = 0;
    uint256 internal constant RETURN_CODE_REQUEST_TO_REVERT_TX = 1;

    uint256 internal constant NONE = 0;
    uint256 internal constant BEFORE_DEPOSIT = 2 ** 1;
    uint256 internal constant AFTER_DEPOSIT = 2 ** 2;
    uint256 internal constant BEFORE_BORROW = 2 ** 3;
    uint256 internal constant AFTER_BORROW = 2 ** 4;
    uint256 internal constant BEFORE_REPAY = 2 ** 5;
    uint256 internal constant AFTER_REPAY = 2 ** 6;
    uint256 internal constant BEFORE_WITHDRAW = 2 ** 7;
    uint256 internal constant AFTER_WITHDRAW = 2 ** 8;
    uint256 internal constant BEFORE_LIQUIDATION = 2 ** 9;
    uint256 internal constant AFTER_LIQUIDATION = 2 ** 10;

    uint256 internal constant BEFORE_SHARE_TRANSFER = 2 ** 11;
    uint256 internal constant AFTER_SHARE_TRANSFER = 2 ** 12;

    function triggerHook(address _hookReceiver, uint24 _hooksBitmap, uint256 _hook) internal pure returns (bool) {
        return _hookReceiver != address(0) && (_hooksBitmap & _hook != 0);
    }
}
