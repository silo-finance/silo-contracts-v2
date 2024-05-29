// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISilo} from "../interfaces/ISilo.sol";

// solhint-disable private-vars-leading-underscore
library Hook {
    struct BeforeDepositInput {
        uint256 assets;
        uint256 shares;
        address receiver;
    }

    struct AfterDepositInput {
        uint256 assets;
        uint256 shares;
        address receiver;
        uint256 receivedAssets;
        uint256 mintedShares;
    }

    struct BeforeWithdrawInput {
        uint256 assets;
        uint256 shares;
        address receiver;
        address owner;
        address spender;
    }

    struct AfterWithdrawInput {
        uint256 assets;
        uint256 shares;
        address receiver;
        address owner;
        address spender;
        uint256 withdrawnAssets;
        uint256 withdrawnShares;
    }

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

    // note: currently we can support hook value up to 2 ** 23,
    // because for optimisation purposes, we storing hooks as uint24

    uint256 internal constant LEVERAGE_SAME_ASSET = BORROW | LEVERAGE | SAME_ASSET;

    // For decoding packed data
    uint256 private constant PACKED_ADDRESS_LENGTH = 20;
    uint256 private constant PACKED_FULL_LENGTH = 32;

    function matchAction(uint256 _action, uint256 _expectedHook) internal pure returns (bool) {
        return _action & _expectedHook == _expectedHook;
    }

    function addAction(uint256 _action, uint256 _newAction) internal pure returns (uint256) {
        return _action | _newAction;
    }

    /// @dev please be careful with removing actions, because other hooks might using them
    /// eg when you have `_action = COLLATERAL_TOKEN | PROTECTED_TOKEN | SHARE_TOKEN_TRANSFER`
    /// and you want to remove action on protected token transfer by doing
    /// `remove(_action, PROTECTED_TOKEN | SHARE_TOKEN_TRANSFER)`, the result will be `_action=COLLATERAL_TOKEN`
    /// and it will not trigger collateral token transfer. In this example you should do:
    /// `remove(_action, PROTECTED_TOKEN)`
    function removeAction(uint256 _action, uint256 _actionToRemove) internal pure returns (uint256) {
        return _action & (~_actionToRemove);
    }

    /// @notice Returns the action for depositing a specific collateral type
    /// @param _type The collateral type
    function depositAction(ISilo.CollateralType _type) internal pure returns (uint256) {
        return DEPOSIT | (_type == ISilo.CollateralType.Collateral ? COLLATERAL_TOKEN : PROTECTED_TOKEN);
    }

    /// @notice Returns the action for withdrawing a specific collateral type
    /// @param _type The collateral type
    function withdrawAction(ISilo.CollateralType _type) internal pure returns (uint256) {
        return WITHDRAW | (_type == ISilo.CollateralType.Collateral ? COLLATERAL_TOKEN : PROTECTED_TOKEN);
    }

    /// @notice Returns the action for borrowing
    /// @param _leverage Whether the borrow is a leverage
    /// @param _sameAsset Whether the borrow is on the same asset
    function borrowAction(bool _leverage, bool _sameAsset) internal pure returns (uint256) {
        return BORROW | (_leverage ? LEVERAGE : NONE) | (_sameAsset ? SAME_ASSET : TWO_ASSETS);
    }

    /// @notice Returns the action for collateral transition
    /// @param _type The collateral type
    function transitionCollateralAction(ISilo.CollateralType _type) internal pure returns (uint256) {
        return TRANSITION_COLLATERAL | (_type == ISilo.CollateralType.Collateral ? COLLATERAL_TOKEN : PROTECTED_TOKEN);
    }

    /// @notice Returns the action for switching collateral
    /// @param _toSameAsset Whether the switch is to the same asset
    function switchCollateralAction(bool _toSameAsset) internal pure returns (uint256) {
        return SWITCH_COLLATERAL | (_toSameAsset ? SAME_ASSET : TWO_ASSETS);
    }

    /// @notice Returns the share token transfer action
    /// @param _tokenType The token type (COLLATERAL_TOKEN || PROTECTED_TOKEN || DEBT_TOKEN)
    function shareTokenTransfer(uint256 _tokenType) internal pure returns (uint256) {
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

        input = AfterTokenTransfer(sender, recipient, amount, senderBalance, recipientBalance, totalSupply);
    }

    /// @dev Decodes packed data from the deposit hook
    /// @param packed The packed data (via abi.encodePacked)
    /// @return input decoded
    function beforeDepositDecode(bytes memory packed)
        internal
        pure
        returns (BeforeDepositInput memory input)
    {
        uint256 assets;
        uint256 shares;
        address receiver;

        assembly {
            let pointer := PACKED_FULL_LENGTH
            assets := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            shares := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            receiver := mload(add(packed, pointer))
        }

        input = BeforeDepositInput(assets, shares, receiver);
    }

    /// @dev Decodes packed data from the deposit hook
    /// @param packed The packed data (via abi.encodePacked)
    /// @return input decoded
    function afterDepositDecode(bytes memory packed)
        internal
        pure
        returns (AfterDepositInput memory input)
    {
        uint256 assets;
        uint256 shares;
        address receiver;
        uint256 receivedAssets;
        uint256 mintedShares;

        assembly {
            let pointer := PACKED_FULL_LENGTH
            assets := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            shares := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            receiver := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            receivedAssets := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            mintedShares := mload(add(packed, pointer))
        }

        input = AfterDepositInput(assets, shares, receiver, receivedAssets, mintedShares);
    }

    /// @dev Decodes packed data from the withdraw hook
    /// @param packed The packed data (via abi.encodePacked)
    /// @return input decoded
    function beforeWithdrawDecode(bytes memory packed)
        internal
        pure
        returns (BeforeWithdrawInput memory input)
    {
        uint256 assets;
        uint256 shares;
        address receiver;
        address owner;
        address spender;

        assembly {
            let pointer := PACKED_FULL_LENGTH
            assets := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            shares := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            receiver := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            owner := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            spender := mload(add(packed, pointer))
        }

        input = BeforeWithdrawInput(assets, shares, receiver, owner, spender);
    }

    /// @dev Decodes packed data from the withdraw hook
    /// @param packed The packed data (via abi.encodePacked)
    /// @return input decoded
    function afterWithdrawDecode(bytes memory packed)
        internal
        pure
        returns (AfterWithdrawInput memory input)
    {
        uint256 assets;
        uint256 shares;
        address receiver;
        address owner;
        address spender;
        uint256 withdrawnAssets;
        uint256 withdrawnShares;

        assembly {
            let pointer := PACKED_FULL_LENGTH
            assets := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            shares := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            receiver := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            owner := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            spender := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            withdrawnAssets := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            withdrawnShares := mload(add(packed, pointer))
        }

        input = AfterWithdrawInput(assets, shares, receiver, owner, spender, withdrawnAssets, withdrawnShares);
    }
}
