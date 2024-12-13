// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {EnumerableSet} from "openzeppelin5/utils/structs/EnumerableSet.sol";

import {IVaultIncentivesModule} from "../interfaces/IVaultIncentivesModule.sol";
import {IIncentivesClaimingLogic} from "../interfaces/IIncentivesClaimingLogic.sol";
import {INotificationReceiver} from "../interfaces/INotificationReceiver.sol";

/// @title Vault Incentives Module
contract VaultIncentivesModule is IVaultIncentivesModule, Ownable2Step {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private _markets;
    EnumerableSet.AddressSet private _notificationReceivers;

    mapping(address market => address logic) public marketToLogic;

    constructor() Ownable(msg.sender) {}

    /// @inheritdoc IVaultIncentivesModule
    function addIncentivesClaimingLogic(IIncentivesClaimingLogic _logic, address _market) external onlyOwner {
        require(address(_logic) != address(0), AddressZero());
        require(marketToLogic[_market] == address(0), LogicAlreadyAdded());

        _markets.add(_market);
        marketToLogic[_market] = address(_logic);

        emit IncentivesClaimingLogicAdded(_market, address(_logic));
    }

    /// @inheritdoc IVaultIncentivesModule
    function updateIncentivesClaimingLogic(IIncentivesClaimingLogic _logic, address _market) external onlyOwner {
        require(address(_logic) != address(0), AddressZero());
        require(marketToLogic[_market] != address(0), MarketNotConfigured());

        marketToLogic[_market] = address(_logic);

        emit IncentivesClaimingLogicUpdated(_market, address(_logic));
    }

    /// @inheritdoc IVaultIncentivesModule
    function removeIncentivesClaimingLogic(address _market) external onlyOwner {
        require(marketToLogic[_market] != address(0), LogicNotFound());

        _markets.remove(_market);
        delete marketToLogic[_market];

        emit IncentivesClaimingLogicRemoved(_market);
    }

    /// @inheritdoc IVaultIncentivesModule
    function addNotificationReceiver(INotificationReceiver _notificationReceiver) external onlyOwner {
        require(address(_notificationReceiver) != address(0), AddressZero());
        require(_notificationReceivers.add(address(_notificationReceiver)), NotificationReceiverAlreadyAdded());

        emit NotificationReceiverAdded(address(_notificationReceiver));
    }

    /// @inheritdoc IVaultIncentivesModule
    function removeNotificationReceiver(INotificationReceiver _notificationReceiver) external onlyOwner {
        require(_notificationReceivers.remove(address(_notificationReceiver)), NotificationReceiverNotFound());

        emit NotificationReceiverRemoved(address(_notificationReceiver));
    }

    /// @inheritdoc IVaultIncentivesModule
    function getIncentivesClaimingLogics() external view returns (address[] memory logics) {
        address[] memory markets = _markets.values();

        logics = _getIncentivesClaimingLogics(markets);
    }

    /// @inheritdoc IVaultIncentivesModule
    function getIncentivesClaimingLogics(address[] memory _marketsInput)
        external
        view
        returns (address[] memory logics)
    {
        logics = _getIncentivesClaimingLogics(_marketsInput);
    }

    /// @inheritdoc IVaultIncentivesModule
    function getNotificationReceivers() external view returns (address[] memory receivers) {
        receivers = _notificationReceivers.values();
    }

    /// @dev Internal function to get the incentives claiming logics for a given market.
    /// @param _marketsInput The markets to get the incentives claiming logics for.
    /// @return logics The incentives claiming logics.
    function _getIncentivesClaimingLogics(address[] memory _marketsInput)
        internal
        view
        returns (address[] memory logics)
    {
        logics = new address[](_marketsInput.length);

        for (uint256 i = 0; i < _marketsInput.length; i++) {
            logics[i] = marketToLogic[_marketsInput[i]];
        }
    }
}
