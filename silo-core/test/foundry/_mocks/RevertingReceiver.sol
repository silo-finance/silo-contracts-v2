// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

/// @notice Mock contract that reverts when receiving native tokens
contract RevertingReceiver {
    error NativeTokenNotAccepted();

    receive() external payable {
        revert NativeTokenNotAccepted();
    }

    fallback() external payable {
        revert NativeTokenNotAccepted();
    }
}