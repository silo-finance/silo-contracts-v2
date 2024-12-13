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

    mapping(address market => EnumerableSet.AddressSet incentivesClaimingLogics) private _claimingLogics;

    constructor() Ownable(msg.sender) {}

    /// @inheritdoc IVaultIncentivesModule
    function addIncentivesClaimingLogic(address _market, IIncentivesClaimingLogic _logic) external onlyOwner {
        require(address(_logic) != address(0), AddressZero());
        require(!_marketLogics[_market].contains(address(_logic)), LogicAlreadyAdded());

        if (_marketLogics[_market].length() == 0) {
            _markets.add(_market);
        }

        _marketLogics[_market].add(address(_logic));

        emit IncentivesClaimingLogicAdded(_market, address(_logic));
    }

    /// @inheritdoc IVaultIncentivesModule
    function removeIncentivesClaimingLogic(address _market, IIncentivesClaimingLogic _logic) external onlyOwner {
        require(_marketLogics[_market].contains(address(_logic)), LogicNotFound());

        _marketLogics[_market].remove(address(_logic));

        if (_marketLogics[_market].length() == 0) {
            _markets.remove(_market);
        }

        emit IncentivesClaimingLogicRemoved(_market, address(_logic));
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

    /// @inheritdoc IVaultIncentivesModule
    function getConfiguredMarkets() external view returns (address[] memory markets) {
        markets = _markets.values();
    }

    /// @inheritdoc IVaultIncentivesModule
    function marketIncentivesClaimingLogics(address market) external view returns (address[] memory logics) {
        logics = _marketLogics[market].values();
    }

    /// @dev Internal function to get the incentives claiming logics for a given market.
    /// @param _marketsInput The markets to get the incentives claiming logics for.
    /// @return logics The incentives claiming logics.
    function _getIncentivesClaimingLogics(address[] memory _marketsInput)
        internal
        view
        returns (address[] memory logics)
    {
        uint256 totalLogics;

        for (uint256 i = 0; i < _marketsInput.length; i++) {
            unchecked {
                // safe to uncheck as we will never have more than 2^256 logics
                totalLogics += _marketLogics[_marketsInput[i]].length();
            }
        }

        logics = new address[](totalLogics);

        uint256 index;
        for (uint256 i = 0; i < _marketsInput.length; i++) {
            address[] memory marketLogics = _marketLogics[_marketsInput[i]].values();

            for (uint256 j = 0; j < marketLogics.length; j++) {
                unchecked {
                    // safe to uncheck as we will never have more than 2^256 logics
                    logics[index++] = marketLogics[j];
                }
            }
        }
    }
}
