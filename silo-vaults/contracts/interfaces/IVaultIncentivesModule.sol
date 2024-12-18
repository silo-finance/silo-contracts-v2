// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IIncentivesClaimingLogic} from "./IIncentivesClaimingLogic.sol";
import {INotificationReceiver} from "./INotificationReceiver.sol";

/// @title Vault Incentives Module interface
interface IVaultIncentivesModule {
    event IncentivesClaimingLogicAdded(address indexed market, address logic);
    event IncentivesClaimingLogicRemoved(address indexed market, address logic);
    event NotificationReceiverAdded(address notificationReceiver);
    event NotificationReceiverRemoved(address notificationReceiver);

    error AddressZero();
    error LogicAlreadyAdded();
    error LogicNotFound();
    error NotificationReceiverAlreadyAdded();
    error NotificationReceiverNotFound();
    error MarketAlreadySet();
    error MarketNotConfigured();

    /// @notice Add an incentives claiming logic for the vault.
    /// @param _market The market to add the logic for.
    /// @param _logic The logic to add.
    function addIncentivesClaimingLogic(address _market, IIncentivesClaimingLogic _logic) external;

    /// @notice Remove an incentives claiming logic for the vault.
    /// @param _market The market to remove the logic for.
    /// @param _logic The logic to remove.
    function removeIncentivesClaimingLogic(address _market, IIncentivesClaimingLogic _logic) external;

    /// @notice Add an incentives distribution solution for the vault.
    /// @param _notificationReceiver The solution to add.
    function addNotificationReceiver(INotificationReceiver _notificationReceiver) external;

    /// @notice Remove an incentives distribution solution for the vault.
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
    function getMarketIncentivesClaimingLogics(address _market) external view returns (address[] memory logics);

    /// @notice Get all configured markets for the vault.
    /// @return markets
    function getConfiguredMarkets() external view returns (address[] memory markets);
}

