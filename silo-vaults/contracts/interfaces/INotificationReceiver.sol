// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

/// @title Common interface for Silo Notification Receiver
interface INotificationReceiver {
    /// @dev Informs the contract about token transfer
    /// @param _token address of the token that was transferred
    /// @param _from sender
    /// @param _to receiver
    /// @param _amount amount that was transferred
    function onAfterTransfer(address _token, address _from, address _to, uint256 _amount) external;
}
