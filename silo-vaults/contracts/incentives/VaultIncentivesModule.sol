// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {
    Ownable2StepUpgradeable, OwnableUpgradeable
} from "openzeppelin5-upgradeable/access/Ownable2StepUpgradeable.sol";
import {EnumerableSet} from "openzeppelin5/utils/structs/EnumerableSet.sol";
import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {IVaultIncentivesModule} from "../interfaces/IVaultIncentivesModule.sol";
import {IIncentivesClaimingLogic} from "../interfaces/IIncentivesClaimingLogic.sol";
import {INotificationReceiver} from "../interfaces/INotificationReceiver.sol";
import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {ISiloVault} from "silo-vaults/contracts/interfaces/ISiloVault.sol";

/// @title Vault Incentives Module
contract VaultIncentivesModule is IVaultIncentivesModule, Ownable2StepUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    ISiloVault public vault;

    // TODO: natspec
    EnumerableSet.AddressSet internal _markets;
    // TODO: natspec
    EnumerableSet.AddressSet internal _notificationReceivers;

    mapping(
        IERC4626 market => mapping(IIncentivesClaimingLogic logic => uint256 validAt)
    ) public pendingClaimingLogics;

    mapping(IERC4626 market => EnumerableSet.AddressSet incentivesClaimingLogics) internal _claimingLogics;

    constructor() {
        _disableInitializers();
    }

    /// @dev Reverts if the caller doesn't have the guardian role.
    modifier onlyGuardianRole() {
        address guardian = vault.guardian();

        if (_msgSender() != owner() && _msgSender() != guardian) revert ErrorsLib.NotGuardianRole();

        _;
    }

    function __VaultIncentivesModule_init(address _owner, ISiloVault _vault) external virtual initializer {
        // TODO: inherit from SiloVault, remove Ownable2StepUpgradeable
        __Ownable_init(_owner);

        require(address(_vault) != address(0), AddressZero());

        vault = _vault;
    }

    /// @inheritdoc IVaultIncentivesModule
    function submitIncentivesClaimingLogic(
        IERC4626 _market,
        IIncentivesClaimingLogic _logic
    ) external virtual onlyOwner {
        require(address(_logic) != address(0), AddressZero());
        require(!_claimingLogics[_market].contains(address(_logic)), LogicAlreadyAdded());
        require(pendingClaimingLogics[_market][_logic] == 0, LogicAlreadyPending());

        uint256 timelock = vault.timelock();

        unchecked { pendingClaimingLogics[_market][_logic] = block.timestamp + timelock; }

        emit SubmitIncentivesClaimingLogic(_market, _logic);
    }

    /// @inheritdoc IVaultIncentivesModule
    function acceptIncentivesClaimingLogic(
        IERC4626 _market,
        IIncentivesClaimingLogic _logic
    ) external virtual {
        uint256 validAt = pendingClaimingLogics[_market][_logic];
        require(validAt != 0 && validAt < block.timestamp, CantAcceptLogic());

        if (_claimingLogics[_market].length() == 0) {
            _markets.add(address(_market));
        }

        _claimingLogics[_market].add(address(_logic));

        delete pendingClaimingLogics[_market][_logic];

        emit IncentivesClaimingLogicAdded(_market, _logic);
    }

    /// @inheritdoc IVaultIncentivesModule
    function removeIncentivesClaimingLogic(IERC4626 _market, IIncentivesClaimingLogic _logic)
        external
        virtual
        onlyOwner
    {
        require(_claimingLogics[_market].contains(address(_logic)), LogicNotFound());

        _claimingLogics[_market].remove(address(_logic));

        if (_claimingLogics[_market].length() == 0) {
            _markets.remove(address(_market));
        }

        emit IncentivesClaimingLogicRemoved(_market, _logic);
    }

    /// @inheritdoc IVaultIncentivesModule
    function revokePendingClaimingLogic(IERC4626 _market, IIncentivesClaimingLogic _logic)
        external
        virtual
        onlyGuardianRole
    {
        delete pendingClaimingLogics[_market][_logic];

        emit RevokePendingClaimingLogic(_market, _logic);
    }

    /// @inheritdoc IVaultIncentivesModule
    function addNotificationReceiver(INotificationReceiver _notificationReceiver) external virtual onlyOwner {
        require(address(_notificationReceiver) != address(0), AddressZero());
        require(_notificationReceivers.add(address(_notificationReceiver)), NotificationReceiverAlreadyAdded());

        emit NotificationReceiverAdded(address(_notificationReceiver));
    }

    /// @inheritdoc IVaultIncentivesModule
    function removeNotificationReceiver(
        INotificationReceiver _notificationReceiver,
        bool _allProgramsStopped
    ) external virtual onlyOwner {
        // sanity check and reminder for anyone who is removing a notification receiver.
        require(_allProgramsStopped, AllProgramsNotStopped());

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
    function getMarketIncentivesClaimingLogics(IERC4626 market)
        external
        view
        virtual
        returns (address[] memory logics)
    {
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
                totalLogics += _claimingLogics[IERC4626(_marketsInput[i])].length();
            }
        }

        logics = new address[](totalLogics);

        uint256 index;
        for (uint256 i = 0; i < _marketsInput.length; i++) {
            address[] memory marketLogics = _claimingLogics[IERC4626(_marketsInput[i])].values();

            for (uint256 j = 0; j < marketLogics.length; j++) {
                unchecked {
                    // safe to uncheck as we will never have more than 2^256 logics
                    logics[index++] = marketLogics[j];
                }
            }
        }
    }
}
