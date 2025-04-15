// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {EnumerableSet} from "openzeppelin5/utils/structs/EnumerableSet.sol";
import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";
import {Initializable} from "openzeppelin5/proxy/utils/Initializable.sol";
import {Context} from "openzeppelin5/utils/Context.sol";

import {IVaultIncentivesModule} from "../interfaces/IVaultIncentivesModule.sol";
import {IIncentivesClaimingLogic} from "../interfaces/IIncentivesClaimingLogic.sol";
import {INotificationReceiver} from "../interfaces/INotificationReceiver.sol";
import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {ISiloVault} from "silo-vaults/contracts/interfaces/ISiloVault.sol";

/// @title Vault Incentives Module
contract VaultIncentivesModule is IVaultIncentivesModule, Initializable, Context {
    using EnumerableSet for EnumerableSet.AddressSet;

    ISiloVault public vault;

    /// @dev Markets that have incentives claiming logics.
    EnumerableSet.AddressSet internal _markets;

    /// @dev Notification receivers that will be notified when a vault's share token balance changes.
    EnumerableSet.AddressSet internal _notificationReceivers;

    /// @dev Pending claiming logics for each market.
    mapping(
        IERC4626 market => mapping(IIncentivesClaimingLogic logic => uint256 validAt)
    ) public pendingClaimingLogics;

    /// @dev Incentives claiming logics for each market.
    mapping(IERC4626 market => EnumerableSet.AddressSet incentivesClaimingLogics) internal _claimingLogics;

    constructor() {
        _disableInitializers();
    }

    /// @dev Reverts if the caller doesn't have the owner role.
    modifier onlyOwner() {
        if (_msgSender() != owner()) revert ErrorsLib.NotOwner();

        _;
    }

    /// @dev Reverts if the caller doesn't have the guardian role.
    modifier onlyGuardianRole() {
        address guardian = vault.guardian();

        if (_msgSender() != owner() && _msgSender() != guardian) revert ErrorsLib.NotGuardianRole();

        _;
    }

    function __VaultIncentivesModule_init(
        ISiloVault _vault,
        address _notificationReceiver,
        IIncentivesClaimingLogic[] memory _claimingLogics,
        IERC4626[] memory _marketsWithIncentives
    ) external virtual initializer {
        require(address(_vault) != address(0), AddressZero());
        require(_claimingLogics.length == _marketsWithIncentives.length, InvalidClaimingLogicsLength());

        vault = _vault;

        if (_notificationReceiver != address(0)) {
            require(_notificationReceivers.add(address(_notificationReceiver)), NotificationReceiverAlreadyAdded());
            emit NotificationReceiverAdded(address(_notificationReceiver));
        }

        for (uint256 i = 0; i < _claimingLogics.length; i++) {
            _addClaimingLogic(_marketsWithIncentives[i], _claimingLogics[i]);
        }
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

        _addClaimingLogic(_market, _logic);
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
        if (_marketsInput.length == 0) return logics;

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

    /// @notice Owner is inherited from the SiloVault contract.
    function owner() public view virtual returns (address) {
        return vault.owner();
    }

    function _addClaimingLogic(IERC4626 _market, IIncentivesClaimingLogic _logic) internal {
        if (_claimingLogics[_market].length() == 0) {
            _markets.add(address(_market));
        }

        _claimingLogics[_market].add(address(_logic));

        delete pendingClaimingLogics[_market][_logic];

        emit IncentivesClaimingLogicAdded(_market, _logic);
    }
}
