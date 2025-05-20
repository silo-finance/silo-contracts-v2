// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {INotificationReceiver} from "silo-vaults/contracts/interfaces/INotificationReceiver.sol";

import {IStream} from "./IStream.sol";

interface IXSiloManagement {
    event NotificationReceiverUpdate(INotificationReceiver indexed newNotificationReceiver);
    event StreamUpdate(IStream indexed newStream);

    error NoChange();
    error StopAllRelatedPrograms();
    error NotBeneficiary();

    /// @dev stream contract, from where xSilo will claim rewards
    function stream() external view returns(IStream);

    /// @dev notification receiver address, it's optional, when empty notifications are not sent
    function notificationReceiver() external view returns(INotificationReceiver);

    /// @notice This function allows setting the notification receiver to address(0).
    /// We know that it is dangerous if there are active incentive programs. Also, it can be an issue if we update to
    /// the new notification receiver while we have active incentive programs. That's why we have sanity check
    /// using `_allProgramsStopped`
    function setNotificationReceiver(INotificationReceiver _notificationReceiver, bool _allProgramsStopped) external;

    /// @dev it sets stream, from where xSilo will claim rewards
    /// stream must have address of current contract set as `BENEFICIARY()`
    function setStream(IStream _stream) external;
}
