// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {ISilo} from "../interfaces/ISilo.sol";

// solhint-disable private-vars-leading-underscore
library Hook {
    /// @notice The data structure for the share token transfer hook
    /// @param sender The sender of the transfer (address(0) on mint)
    /// @param recipient The recipient of the transfer (address(0) on burn)
    /// @param amount The amount of tokens transferred/minted/burned
    /// @param senderBalance The balance of the sender after the transfer (empty on mint)
    /// @param recipientBalance The balance of the recipient after the transfer (empty on burn)
    /// @param totalSupply The total supply of the share token
    struct AfterTokenTransfer {
        address sender;
        address recipient;
        uint256 amount;
        uint256 senderBalance;
        uint256 recipientBalance;
        uint256 totalSupply;
    }

    /// @notice Supported hooks
    /// @dev The hooks are stored as a bitmap and can be combined with bitwise OR
    uint256 internal constant NONE = 0;
    // uint256 internal constant DEPOSIT = 2 ** 1;
    // uint256 internal constant BORROW = 2 ** 2;
    // uint256 internal constant BORROW_SAME_ASSET = 2 ** 3; // deprecated
    // uint256 internal constant REPAY = 2 ** 4;
    // uint256 internal constant WITHDRAW = 2 ** 5;
    // uint256 internal constant FLASH_LOAN = 2 ** 6;
    // uint256 internal constant TRANSITION_COLLATERAL = 2 ** 7;
    // uint256 internal constant SWITCH_COLLATERAL = 2 ** 8; // deprecated
    uint256 internal constant SHARE_TOKEN_TRANSFER = 2 ** 10;
    uint256 internal constant COLLATERAL_TOKEN = 2 ** 11;
    // uint256 internal constant PROTECTED_TOKEN = 2 ** 12;
    uint256 internal constant DEBT_TOKEN = 2 ** 13;

    // note: currently we can support hook value up to 2 ** 23,
    // because for optimisation purposes, we storing hooks as uint24

    // For decoding packed data
    uint256 private constant PACKED_ADDRESS_LENGTH = 20;
    uint256 private constant PACKED_FULL_LENGTH = 32;
    uint256 private constant PACKED_ENUM_LENGTH = 1;
    uint256 private constant PACKED_BOOL_LENGTH = 1;

    error FailedToParseBoolean();
    error InvalidTokenType();

    /// @notice Checks if the action has a specific hook
    /// @param _action The action
    /// @param _expectedHook The expected hook
    /// @dev The function returns true if the action has the expected hook.
    /// As hooks actions can be combined with bitwise OR, the following examples are valid:
    /// `matchAction(WITHDRAW | COLLATERAL_TOKEN, WITHDRAW) == true`
    /// `matchAction(WITHDRAW | COLLATERAL_TOKEN, COLLATERAL_TOKEN) == true`
    /// `matchAction(WITHDRAW | COLLATERAL_TOKEN, WITHDRAW | COLLATERAL_TOKEN) == true`
    function matchAction(uint256 _action, uint256 _expectedHook) internal pure returns (bool) {
        return (_action & _expectedHook) == _expectedHook;
    }

    /// @notice Adds a hook to an action
    /// @param _action The action
    /// @param _newAction The new hook to be added
    function addAction(uint256 _action, uint256 _newAction) internal pure returns (uint256) {
        return _action | _newAction;
    }

    /// @dev please be careful with removing actions, because other hooks might using them
    /// eg when you have `_action = COLLATERAL_TOKEN | SHARE_TOKEN_TRANSFER`
    /// and you want to remove action on share token transfer by doing
    /// `remove(_action, SHARE_TOKEN_TRANSFER)`, the result will be `_action=COLLATERAL_TOKEN`
    function removeAction(uint256 _action, uint256 _actionToRemove) internal pure returns (uint256) {
        return _action & (~_actionToRemove);
    }

    /// @notice Returns the share token transfer action
    /// @param _tokenType The token type (COLLATERAL_TOKEN || DEBT_TOKEN)
    function shareTokenTransfer(uint256 _tokenType) internal pure returns (uint256) {
        require(
            _tokenType == COLLATERAL_TOKEN || _tokenType == DEBT_TOKEN,
            InvalidTokenType()
        );

        return SHARE_TOKEN_TRANSFER | _tokenType;
    }

    /// @dev Decodes packed data from the share token after the transfer hook
    /// @param packed The packed data (via abi.encodePacked)
    /// @return input decoded
    function afterTokenTransferDecode(bytes memory packed)
        internal
        pure
        returns (AfterTokenTransfer memory input)
    {
        address sender;
        address recipient;
        uint256 amount;
        uint256 senderBalance;
        uint256 recipientBalance;
        uint256 totalSupply;

        assembly { // solhint-disable-line no-inline-assembly
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

        input = AfterTokenTransfer(sender, recipient, amount, senderBalance, recipientBalance, totalSupply);
    }

    /// @dev Converts a uint8 to a boolean
    function _toBoolean(uint8 _value) internal pure returns (bool result) {
        if (_value == 0) {
            result = false;
        } else if (_value == 1) {
            result = true;
        } else {
            revert FailedToParseBoolean();
        }
    }
}
