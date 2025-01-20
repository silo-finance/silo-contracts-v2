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

    EnumerableSet.AddressSet internal _markets;
    EnumerableSet.AddressSet internal _notificationReceivers;

    mapping(address market => EnumerableSet.AddressSet incentivesClaimingLogics) internal _claimingLogics;

    constructor(address _owner) Ownable(_owner) {}

    /// @inheritdoc IVaultIncentivesModule
    function addIncentivesClaimingLogic(address _market, IIncentivesClaimingLogic _logic) external virtual onlyOwner {
        require(address(_logic) != address(0), AddressZero());
        require(!_claimingLogics[_market].contains(address(_logic)), LogicAlreadyAdded());

        if (_claimingLogics[_market].length() == 0) {
            _markets.add(_market);
        }

        _claimingLogics[_market].add(address(_logic));

        emit IncentivesClaimingLogicAdded(_market, address(_logic));
    }

    /// @inheritdoc IVaultIncentivesModule
    function removeIncentivesClaimingLogic(address _market, IIncentivesClaimingLogic _logic)
        external
        virtual
        onlyOwner
    {
        require(_claimingLogics[_market].contains(address(_logic)), LogicNotFound());

        _claimingLogics[_market].remove(address(_logic));

        if (_claimingLogics[_market].length() == 0) {
            _markets.remove(_market);
        }

        emit IncentivesClaimingLogicRemoved(_market, address(_logic));
    }

    /// @inheritdoc IVaultIncentivesModule
    function addNotificationReceiver(INotificationReceiver _notificationReceiver) external virtual onlyOwner {
        require(address(_notificationReceiver) != address(0), AddressZero());
        require(_notificationReceivers.add(address(_notificationReceiver)), NotificationReceiverAlreadyAdded());

        emit NotificationReceiverAdded(address(_notificationReceiver));
    }

    /// @inheritdoc IVaultIncentivesModule
    function removeNotificationReceiver(INotificationReceiver _notificationReceiver) external virtual onlyOwner {
        require(_notificationReceivers.remove(address(_notificationReceiver)), NotificationReceiverNotFound());

        emit NotificationReceiverRemoved(address(_notificationReceiver));
    }

    /// @inheritdoc IVaultIncentivesModule
    function getAllIncentivesClaimingLogics() external view virtual returns (address[] memory logics) {
        address[] memory markets = _markets.values();

        logics = _getAllIncentivesClaimingLogics(markets);
    }

    /// @inheritdoc IVaultIncentivesModule
    function getMarketsIncentivesClaimingLogics(address[] calldata _marketsInput)
        external
        view
        virtual
        returns (address[] memory logics)
    {
        logics = _getAllIncentivesClaimingLogics(_marketsInput);
    }

    /// @inheritdoc IVaultIncentivesModule
    function getNotificationReceivers() external view virtual returns (address[] memory receivers) {
        receivers = _notificationReceivers.values();
    }

    /// @inheritdoc IVaultIncentivesModule
    function getConfiguredMarkets() external view virtual returns (address[] memory markets) {
        markets = _markets.values();
    }

    /// @inheritdoc IVaultIncentivesModule
    function getMarketIncentivesClaimingLogics(address market) external view virtual returns (address[] memory logics) {
        logics = _claimingLogics[market].values();
    }

    /// @dev Internal function to get the incentives claiming logics for a given market.
    /// @param _marketsInput The markets to get the incentives claiming logics for.
    /// @return logics The incentives claiming logics.
    function _getAllIncentivesClaimingLogics(address[] memory _marketsInput)
        internal
        view
        virtual
        returns (address[] memory logics)
    {
        uint256 totalLogics;

        for (uint256 i = 0; i < _marketsInput.length; i++) {
            unchecked {
                // safe to uncheck as we will never have more than 2^256 logics
                totalLogics += _claimingLogics[_marketsInput[i]].length();
            }
        }

        logics = new address[](totalLogics);

        uint256 index;
        for (uint256 i = 0; i < _marketsInput.length; i++) {
            address[] memory marketLogics = _claimingLogics[_marketsInput[i]].values();

            for (uint256 j = 0; j < marketLogics.length; j++) {
                unchecked {
                    // safe to uncheck as we will never have more than 2^256 logics
                    logics[index++] = marketLogics[j];
                }
            }
        }
    }
}
