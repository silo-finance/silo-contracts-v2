// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {IIncentivesClaimingLogic} from "silo-vaults/contracts/interfaces/IIncentivesClaimingLogic.sol";
import {INotificationReceiver} from "silo-vaults/contracts/interfaces/INotificationReceiver.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

interface IIncentiveHook {
    event IncentivesClaimingLogicAdded(ISilo indexed silo, IIncentivesClaimingLogic indexed logic);
    event IncentivesClaimingLogicRemoved(ISilo indexed silo, IIncentivesClaimingLogic indexed logic);

    event NotificationReceiverAdded(IShareToken indexed shareToken, INotificationReceiver indexed receiver);
    event NotificationReceiverRemoved(IShareToken indexed shareToken, INotificationReceiver indexed receiver);

    error OwnerIsZeroAddress();
    error ClaimingLogicAlreadyAdded();
    error ClaimingLogicNotAdded();
    error NotificationReceiverAlreadyAdded();
    error NotificationReceiverNotAdded();

    /// @notice Add an incentives claiming logic for the silo.
    /// @param _silo The silo to add the logic for.
    /// @param _logic The logic to add.
    function addIncentivesClaimingLogic(ISilo _silo, IIncentivesClaimingLogic _logic) external;

    /// @notice Remove an incentives claiming logic for the silo.
    /// @param _silo The silo to remove the logic for.
    /// @param _logic The logic to remove.
    function removeIncentivesClaimingLogic(ISilo _silo, IIncentivesClaimingLogic _logic) external;

    /// @notice Add an incentives distribution solution for the vault.
    /// @param _shareToken The share token to add the solution for.
    /// @param _notificationReceiver The solution to add.
    function addNotificationReceiver(
        IShareToken _shareToken,
        INotificationReceiver _notificationReceiver
    ) external;

    /// @notice Remove an incentives distribution solution for the vault.
    /// @dev It is very important to be careful when you remove a notification receiver from the incentive module.
    /// All ongoing incentive distributions must be stopped before removing a notification receiver.
    /// @param _shareToken The share token to remove the solution for.
    /// @param _notificationReceiver The solution to remove.
    /// @param _allProgramsStopped Reminder for anyone who is removing a notification receiver.
    function removeNotificationReceiver(
        IShareToken _shareToken,
        INotificationReceiver _notificationReceiver,
        bool _allProgramsStopped
    ) external;

    /// @notice Get configured incentives claiming logics.
    /// @param _silo The silo to get the incentives claiming logics for.
    /// @return logics
    function getIncentivesClaimingLogics(ISilo _silo) external view returns (address[] memory logics);

    /// @notice Get configured notification receivers for a share token.
    /// @param _shareToken The share token to get the notification receivers for.
    /// @return receivers
    function getNotificationReceivers(IShareToken _shareToken) external view returns (address[] memory receivers);
}
