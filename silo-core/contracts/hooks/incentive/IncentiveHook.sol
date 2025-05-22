// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {EnumerableSet} from "openzeppelin5/utils/structs/EnumerableSet.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";

import {IIncentivesClaimingLogic} from "silo-vaults/contracts/interfaces/IIncentivesClaimingLogic.sol";
import {INotificationReceiver} from "silo-vaults/contracts/interfaces/INotificationReceiver.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";
import {IIncentiveHook} from "silo-core/contracts/interfaces/IIncentiveHook.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {BaseHookReceiver} from "silo-core/contracts/hooks/_common/BaseHookReceiver.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";

/// @title IncentiveHook
/// @dev This contract is designed to be used as a hook receiver for Silo contracts.
/// It allows an owner to register incentive claiming logics for different silos and notification receivers for share tokens.
/// The `beforeAction` hook is used to claim incentives before any Silo action (deposit, withdraw, borrow, etc.).
/// The `afterAction` hook is used to notify registered receivers after a share token transfer.
abstract contract IncentiveHook is BaseHookReceiver, Ownable2Step, IIncentiveHook {
    using EnumerableSet for EnumerableSet.AddressSet;
    using Hook for uint256;
    using Hook for bytes;

    /// @notice Maps a Silo to a set of addresses representing incentive claiming logics.
    mapping(ISilo silo => EnumerableSet.AddressSet claimingLogics) internal _claimingLogics;
    /// @notice Maps a share token to a set of addresses representing notification receivers.
    mapping(IShareToken shareToken => EnumerableSet.AddressSet notificationReceivers) internal _notificationReceivers;

    /// @notice Transient variable to store the action type for which `beforeAction` was executed.
    /// @dev This is used in `afterAction` to determine if incentives need to be claimed for token transfers.
    uint256 transient beforeActionExecutedFor;

    /// @dev The ownership is transferred to address(0) to lock the implementation, preventing re-initialization.
    constructor() Ownable(msg.sender) {
        _transferOwnership(address(0));
    }

    /// @inheritdoc IIncentiveHook
    function addIncentivesClaimingLogic(
        ISilo _silo,
        IIncentivesClaimingLogic _logic
    )
        external
        onlyOwner
    {
        (address silo0, address silo1) = siloConfig.getSilos();
        require(_silo == ISilo(silo0) || _silo == ISilo(silo1), InvalidSilo());
        require(address(_logic) != address(0), ZeroAddress());
        require(_claimingLogics[_silo].add(address(_logic)), ClaimingLogicAlreadyAdded());
        emit IncentivesClaimingLogicAdded(_silo, _logic);

        _configureHooksIfNotConfigured(address(_silo));
    }

    /// @inheritdoc IIncentiveHook
    function removeIncentivesClaimingLogic(
        ISilo _silo,
        IIncentivesClaimingLogic _logic
    )
        external
        onlyOwner
    {
        require(_claimingLogics[_silo].remove(address(_logic)), ClaimingLogicNotAdded());
        emit IncentivesClaimingLogicRemoved(_silo, _logic);
    }

    /// @inheritdoc IIncentiveHook
    function addNotificationReceiver(
        IShareToken _shareToken,
        INotificationReceiver _notificationReceiver
    )
        external
        onlyOwner
    {
        require(address(_notificationReceiver) != address(0), ZeroAddress());
        require(_validShareToken(address(_shareToken)), InvalidShareToken());
        require(
            _notificationReceivers[_shareToken].add(address(_notificationReceiver)),
            NotificationReceiverAlreadyAdded()
        );

        address silo = address(_shareToken.silo());

        uint256 tokenType = _getTokenType(silo, address(_shareToken));
        uint256 hooksAfter = _getHooksAfter(silo);

        uint256 action = tokenType | Hook.SHARE_TOKEN_TRANSFER;

        // If the action is not already configured, add it.
        if (!hooksAfter.matchAction(action)) {
            hooksAfter = hooksAfter.addAction(action);
            _setHookConfig(silo, uint24(_getHooksBefore(silo)), uint24(hooksAfter));
        }

        emit NotificationReceiverAdded(_shareToken, _notificationReceiver);
    }

    /// @inheritdoc IIncentiveHook
    function removeNotificationReceiver(
        IShareToken _shareToken,
        INotificationReceiver _notificationReceiver,
        bool _allProgramsStopped
    ) external onlyOwner {
        // this is a sanity to remind that we need to stop all programs
        require(_allProgramsStopped, AllProgramsNotStopped());
        require(
            _notificationReceivers[_shareToken].remove(address(_notificationReceiver)),
            NotificationReceiverNotAdded()
        );
        emit NotificationReceiverRemoved(_shareToken, _notificationReceiver);
    }

    /// @inheritdoc IHookReceiver
    function beforeAction(address _silo, uint256 _action, bytes calldata)
        public
        virtual
        override
    {
        _claimIncentives(_silo);
        beforeActionExecutedFor = _action;
    }

    /// @inheritdoc IHookReceiver
    function afterAction(address _silo, uint256 _action, bytes calldata _inputAndOutput)
        public
        virtual
        override
    {
        address[] memory receivers = _notificationReceivers[IShareToken(msg.sender)].values();

        if (receivers.length == 0 ||!_getHooksAfter(_silo).matchAction(_action)) return;

        if (beforeActionExecutedFor == Hook.NONE) { // This is a token transfer, and we need to claim the incentives.
            _claimIncentives(_silo);
        }

        Hook.AfterTokenTransfer memory input = _inputAndOutput.afterTokenTransferDecode();

        for (uint256 i = 0; i < receivers.length; i++) {
            INotificationReceiver(receivers[i]).afterTokenTransfer(
                input.sender,
                input.senderBalance,
                input.recipient,
                input.recipientBalance,
                input.totalSupply,
                input.amount
            );
        }
    }

    /// @inheritdoc IIncentiveHook
    function getIncentivesClaimingLogics(ISilo _silo) external view returns (address[] memory logics) {
        logics = _claimingLogics[_silo].values();
    }

    /// @inheritdoc IIncentiveHook
    function getNotificationReceivers(IShareToken _shareToken) external view returns (address[] memory receivers) {
        receivers = _notificationReceivers[_shareToken].values();
    }

    /// @notice Claim incentives for the silo
    /// @param _silo Silo address
    function _claimIncentives(address _silo) internal {
        uint256 numberOfClaimingLogics = _claimingLogics[ISilo(_silo)].length();
        if (numberOfClaimingLogics == 0) return;

        for (uint256 i = 0; i < numberOfClaimingLogics; i++) {
            address claimingLogic = address(_claimingLogics[ISilo(_silo)].at(i));
            bytes memory input = abi.encodePacked(IIncentivesClaimingLogic.claimRewardsAndDistribute.selector);

            (bool success,) = ISilo(_silo).callOnBehalfOfSilo({
                _target: claimingLogic,
                _value: 0,
                _callType: ISilo.CallType.Delegatecall,
                _input: input
            });

            if (!success) {
                emit FailedToClaimIncentives(_silo, claimingLogic);
            }
        }
    }

    /// @notice Get the token type for the share token
    /// @param _silo Silo address for which tokens was deployed
    /// @param _shareToken Share token address
    /// @dev Revert if wrong silo
    /// @dev Revert if the share token is not one of the collateral, protected or debt tokens
    function _getTokenType(address _silo, address _shareToken) internal view virtual returns (uint256) {
        (
            address protectedShareToken,
            address collateralShareToken,
            address debtShareToken
        ) = siloConfig.getShareTokens(_silo);

        if (_shareToken == collateralShareToken) return Hook.COLLATERAL_TOKEN;
        if (_shareToken == protectedShareToken) return Hook.PROTECTED_TOKEN;
        if (_shareToken == debtShareToken) return Hook.DEBT_TOKEN;

        revert InvalidShareToken();
    }

    /// @notice Check if the share token is valid
    /// @param _shareToken Share token address
    function _validShareToken(address _shareToken) internal view returns (bool isValid) {
        (address silo0, address silo1) = siloConfig.getSilos();

        address protected;
        address collateral;
        address debt;

        (protected, collateral, debt) = siloConfig.getShareTokens(silo0);
        isValid = _shareToken == collateral || _shareToken == protected || _shareToken == debt;

        if (isValid) return true;

        (protected, collateral, debt) = siloConfig.getShareTokens(silo1);
        isValid = _shareToken == collateral || _shareToken == protected || _shareToken == debt;
    }

    /// @notice Configure the hooks for the silo
    /// @param _silo Silo address
    /// @dev Actions to be configured:
    /// - DEPOSIT
    /// - WITHDRAW
    /// - BORROW
    /// - BORROW_SAME_ASSET
    /// - REPAY
    /// - TRANSITION_COLLATERAL
    /// - SWITCH_COLLATERAL
    /// - LIQUIDATION
    /// - FLASH_LOAN
    function _configureHooksIfNotConfigured(address _silo) internal {
        uint256 hooksBefore = uint256(_getHooksBefore(_silo));

        uint256 allHooks = Hook.DEPOSIT |
            Hook.WITHDRAW |
            Hook.BORROW |
            Hook.BORROW_SAME_ASSET |
            Hook.REPAY |
            Hook.TRANSITION_COLLATERAL |
            Hook.SWITCH_COLLATERAL |
            Hook.LIQUIDATION |
            Hook.FLASH_LOAN;
            // Share token transfer ignored as it has no before token transfer hook.

        if (hooksBefore != allHooks) {
            _setHookConfig(_silo, uint24(allHooks), uint24(_getHooksAfter(_silo)));
        }
    }

   /// @notice Set the owner of the hook receiver
    /// @param _owner Owner address
    function __IncentiveHook_init(address _owner)
        internal
        onlyInitializing
        virtual
    {
        require(_owner != address(0), OwnerIsZeroAddress());

        _transferOwnership(_owner);
    }
}
