// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IHookReceiver} from "../utils/hook-receivers/interfaces/IHookReceiver.sol";

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
    uint256 internal constant LEVERAGE = 2 ** 9;
    uint256 internal constant FLASH_LOAN = 2 ** 10;
    uint256 internal constant TRANSITION_COLLATERAL = 2 ** 11;
    uint256 internal constant SWITCH_COLLATERAL = 2 ** 12;
    uint256 internal constant LIQUIDATION = 2 ** 13;
    uint256 internal constant SHARE_TOKEN_TRANSFER = 2 ** 14;
    uint256 internal constant COLLATERAL_TOKEN = 2 ** 15;
    uint256 internal constant PROTECTED_TOKEN = 2 ** 16;
    uint256 internal constant DEBT_TOKEN = 2 ** 17;


//    uint256 internal constant BEFORE_DEPOSIT = 2 ** 3 | 2 ** 5;
//    uint256 internal constant AFTER_DEPOSIT = 2 ** 4 | 2 ** 5;
//    uint256 internal constant BORROW_SAME_ASSET = 2 ** 6 | 2 ** 1;
//    uint256 internal constant BORROW_TWO_ASSETS = 2 ** 6 | 2 ** 2;
//    uint256 internal constant BEFORE_REPAY = 2 ** 3 | 2 ** 7;
//    uint256 internal constant AFTER_REPAY = 2 ** 4 | 2 ** 7;
//    uint256 internal constant BEFORE_WITHDRAW = 2 ** 3 | 2 ** 8;
//    uint256 internal constant AFTER_WITHDRAW = 2 ** 4 | 2 ** 8;
//    uint256 internal constant BEFORE_LIQUIDATION = 2 ** 3 | 2 ** 9;
//    uint256 internal constant AFTER_LIQUIDATION = 2 ** 4 | 2 ** 9;
//
//    uint256 internal constant BEFORE_SHARE_TRANSFER = 2 ** 3 | 2 ** 10;
//    uint256 internal constant AFTER_SHARE_TRANSFER = 2 ** 4 | 2 ** 10;
//
//    uint256 internal constant BEFORE_TRANSITION_COLLATERAL = 2 ** 3 | 2 ** 11;
//    uint256 internal constant AFTER_TRANSITION_COLLATERAL = 2 ** 4 | 2 ** 11;
//
//    uint256 internal constant BEFORE_SWITCH_COLLATERAL = 2 ** 3 | 2 ** 12;
//    uint256 internal constant AFTER_SWITCH_COLLATERAL = 2 ** 4 | 2 ** 12;

    function beforeActionCall(IHookReceiver _hookReceiver, address _silo, uint256 _hookAction, bytes memory _data)
        internal
    {
        _callHook(address(_hookReceiver), IHookReceiver.beforeAction.selector, _silo, _hookAction, _data);
    }

    function beforeActionCall(IHookReceiver _hookReceiver, uint256 _hookAction, bytes memory _data)
        internal
    {
        _callHook(address(_hookReceiver), IHookReceiver.beforeAction.selector, address(this), _hookAction, _data);
    }

    function afterActionCall(IHookReceiver _hookReceiver, address _silo, uint256 _hookAction, bytes memory _data)
        internal
    {
        _callHook(address(_hookReceiver), IHookReceiver.afterAction.selector, _silo, _hookAction, _data);
    }

    function afterActionCall(IHookReceiver _hookReceiver, uint256 _hookAction, bytes memory _data) internal {
        _callHook(address(_hookReceiver), IHookReceiver.afterAction.selector, address(this), _hookAction, _data);
    }

    function _callHook(
        address _hookReceiver,
        bytes4 _selector,
        address _silo,
        uint256 _hookAction,
        bytes memory _data
    )
        private
    {
        if (_hookReceiver == address(0)) return;

        (bool callSuccessful, bytes memory code) = _hookReceiver.call( // solhint-disable-line avoid-low-level-calls
            abi.encodeWithSelector(_selector, _silo, _hookAction, _data)
        );

        if (!callSuccessful || code.length == 0) return;

        if (abi.decode(code, (uint256)) == RETURN_CODE_REQUEST_TO_REVERT_TX) {
            revert IHookReceiver.RevertRequestFromHook();
        }
    }
}
