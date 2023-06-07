// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

/// @notice Checker for whitelisted (smart contract) wallets which are allowed to deposit.
/// The goal is to prevent tokenizing the escrow.
interface ISmartWalletChecker {
    function check(address _wallet) external;
}
