// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

/// @notice Checker for whitelisted (smart contract) wallets which are allowed to deposit.
/// The goal is to prevent tokenizing the escrow.
interface ISmartWalletChecker {
    function check(address _wallet) external;
    function allowlistAddress(address _wallet) external;
}
