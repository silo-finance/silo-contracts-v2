// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {IIncentivesClaimingLogic} from "./IIncentivesClaimingLogic.sol";
import {INotificationReceiver} from "./INotificationReceiver.sol";

/// @title Vault Incentives Module interface
interface IVaultIncentivesModule {
    event IncentivesClaimingLogicAdded(IERC4626 indexed market, IIncentivesClaimingLogic logic);
    event IncentivesClaimingLogicRemoved(IERC4626 indexed market, IIncentivesClaimingLogic logic);
    event SubmitIncentivesClaimingLogic(IERC4626 indexed market, IIncentivesClaimingLogic logic);
    event RevokePendingClaimingLogic(IERC4626 indexed market, IIncentivesClaimingLogic logic);
    event NotificationReceiverAdded(address notificationReceiver);
    event NotificationReceiverRemoved(address notificationReceiver);

    error AddressZero();
    error LogicAlreadyAdded();
    error LogicNotFound();
    error LogicAlreadyPending();
    error LogicNotPending();
    error CantAcceptLogic();
    error NotificationReceiverAlreadyAdded();
    error NotificationReceiverNotFound();
    error MarketAlreadySet();
    error MarketNotConfigured();

    /// @notice Submit an incentives claiming logic for the vault.
    /// @param _market The market to add the logic for.
    /// @param _logic The logic to add.
    function submitIncentivesClaimingLogic(IERC4626 _market, IIncentivesClaimingLogic _logic) external;

    /// @notice Accept an incentives claiming logic for the vault.
    /// @param _market The market to accept the logic for.
    /// @param _logic The logic to accept.
    function acceptIncentivesClaimingLogic(IERC4626 _market, IIncentivesClaimingLogic _logic) external;

    /// @notice Remove an incentives claiming logic for the vault.
    /// @param _market The market to remove the logic for.
    /// @param _logic The logic to remove.
    function removeIncentivesClaimingLogic(IERC4626 _market, IIncentivesClaimingLogic _logic) external;

    /// @notice Revoke a pending incentives claiming logic for the vault.
    /// @param _market The market to revoke the logic for.
    /// @param _logic The logic to revoke.
    function revokePendingClaimingLogic(IERC4626 _market, IIncentivesClaimingLogic _logic) external;

    /// @notice Add an incentives distribution solution for the vault.
    /// @param _notificationReceiver The solution to add.
    function addNotificationReceiver(INotificationReceiver _notificationReceiver) external;

    /// @notice Remove an incentives distribution solution for the vault.
    /// @dev It is very important to be careful when you remove a notification receiver from the incentive module.
    /// All ongoing incentive distributions must be stopped before removing a notification receiver.
    /// @param _notificationReceiver The solution to remove.
    function removeNotificationReceiver(INotificationReceiver _notificationReceiver) external;

    /// @notice Get all incentives claiming logics for the vault.
    /// @return logics The logics.
    function getAllIncentivesClaimingLogics() external view returns (address[] memory logics);

    /// @notice Get all incentives claiming logics for the vault.
    /// @param _markets The markets to get the incentives claiming logics for.
    /// @return logics The logics.
    function getMarketsIncentivesClaimingLogics(address[] calldata _markets)
        external
        view
        returns (address[] memory logics);

    /// @notice Get all incentives distribution solutions for the vault.
    /// @return _notificationReceivers
    function getNotificationReceivers() external view returns (address[] memory _notificationReceivers);

    /// @notice Get incentives claiming logics for a market.
    /// @param _market The market to get the incentives claiming logics for.
    /// @return logics
    function getMarketIncentivesClaimingLogics(IERC4626 _market) external view returns (address[] memory logics);

    /// @notice Get all configured markets for the vault.
    /// @return markets
    function getConfiguredMarkets() external view returns (address[] memory markets);
}

