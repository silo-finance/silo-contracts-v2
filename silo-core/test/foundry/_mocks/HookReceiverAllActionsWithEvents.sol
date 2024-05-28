// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {SiloHookReceiver, IHookReceiver} from "silo-core/contracts/utils/hook-receivers/_common/SiloHookReceiver.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

/// @dev Hook receiver for all actions with events to see decoded inputs
/// This contract is designed to be deployed for each test case
contract HookReceiverAllActionsWithEvents is SiloHookReceiver {
    using Hook for uint256;

    bool constant IS_BEFORE = true;
    bool constant IS_AFTER = false;

    uint24 internal immutable _SILO0_ACTIONS_BEFORE;
    uint24 internal immutable _SILO0_ACTIONS_AFTER;
    uint24 internal immutable _SILO1_ACTIONS_BEFORE;
    uint24 internal immutable _SILO1_ACTIONS_AFTER;

    ISiloConfig public siloConfig;

    bool public revertAllActions;

    // Events to be emitted by the hook receiver to see decoded inputs
    // HA - Hook Action
    event DepositBeforeHA(
        address silo,
        uint256 assets,
        uint256 shares,
        address receiver,
        ISilo.CollateralType collateralType
    );

    event DepositAfterHA(
        address silo,
        uint256 depositedAssets,
        uint256 depositedShares,
        uint256 receivedAssets, // The exact amount of assets being deposited
        uint256 mintedShares, // The exact amount of shares being minted
        address receiver,
        ISilo.CollateralType collateralType
    );

    event ShareTokenAfterHA(
        address silo,
        address sender,
        address recipient,
        uint256 amount,
        uint256 senderBalance,
        uint256 recipientBalance,
        uint256 totalSupply,
        ISilo.CollateralType collateralType
    );

    event WithdrawBeforeHA(
        address silo,
        uint256 assets,
        uint256 shares,
        address receiver,
        address owner,
        address spender,
        ISilo.CollateralType collateralType
    );

    event WithdrawAfterHA(
        address silo,
        uint256 assets,
        uint256 shares,
        address receiver,
        address owner,
        address spender,
        uint256 withdrawnAssets,
        uint256 withdrawnShares,
        ISilo.CollateralType collateralType
    );

    error ActionsStopped();
    error ShareTokenBeforeForbidden();

    // designed to be deployed for each test case
    constructor(
        uint256 _silo0ActionsBefore,
        uint256 _silo0ActionsAfter,
        uint256 _silo1ActionsBefore,
        uint256 _silo1ActionsAfter
    ) {
        _SILO0_ACTIONS_BEFORE = uint24(_silo0ActionsBefore);
        _SILO0_ACTIONS_AFTER = uint24(_silo0ActionsAfter);
        _SILO1_ACTIONS_BEFORE = uint24(_silo1ActionsBefore);
        _SILO1_ACTIONS_AFTER = uint24(_silo1ActionsAfter);
    }

    /// @inheritdoc IHookReceiver
    function initialize(ISiloConfig _siloConfig, bytes calldata) external {
        siloConfig = _siloConfig;

        (address silo0, address silo1) = siloConfig.getSilos();

        // Set hooks for all actions for both silos
        _setHookConfig(silo0, _SILO0_ACTIONS_BEFORE, _SILO0_ACTIONS_AFTER);
        _setHookConfig(silo1, _SILO1_ACTIONS_BEFORE, _SILO1_ACTIONS_AFTER);
    }

    function revertAnyAction() external {
        revertAllActions = true;
    }

    /// @inheritdoc IHookReceiver
    function beforeAction(address _silo, uint256 _action, bytes calldata _inputAndOutput) external {
        if (revertAllActions) revert ActionsStopped();
        _processActions(_silo, _action, _inputAndOutput, IS_BEFORE);
    }

    /// @inheritdoc IHookReceiver
    function afterAction(address _silo, uint256 _action, bytes calldata _inputAndOutput) external {
        if (revertAllActions) revert ActionsStopped();
        _processActions(_silo, _action, _inputAndOutput, IS_AFTER);
    }

    function _processActions(address _silo, uint256 _action, bytes calldata _inputAndOutput, bool _isBefore) internal {
        if (_action.matchAction(Hook.DEPOSIT)) {
            _processDeposit(_silo, _action, _inputAndOutput, _isBefore);
        } else if (_action.matchAction(Hook.SHARE_TOKEN_TRANSFER)) {
            _processShareTokenTransfer(_silo, _action, _inputAndOutput, _isBefore);
        } else if (_action.matchAction(Hook.WITHDRAW)) {
            _processWithdraw(_silo, _action, _inputAndOutput, _isBefore);
        }
    }

    function _processDeposit(address _silo, uint256 _action, bytes calldata _inputAndOutput, bool _isBefore) internal {
        bool isCollateral = _action.matchAction(Hook.depositAction(ISilo.CollateralType.Collateral));

        ISilo.CollateralType collateralType = isCollateral
                ? ISilo.CollateralType.Collateral
                : ISilo.CollateralType.Protected;

        if (_isBefore) {
            (uint256 assets, uint256 shares, address receiver) = Hook.beforeDepositDecode(_inputAndOutput);
            emit DepositBeforeHA(_silo, assets, shares, receiver, collateralType);
        } else {
            (
                uint256 depositedAssets,
                uint256 depositedShares,
                address receiver,
                uint256 receivedAssets,
                uint256 mintedShares
            ) = Hook.afterDepositDecode(_inputAndOutput);

            emit DepositAfterHA(
                _silo,
                depositedAssets,
                depositedShares,
                receivedAssets,
                mintedShares,
                receiver,
                collateralType
            );
        }
    }

    function _processShareTokenTransfer(
        address _silo,
        uint256 _action,
        bytes calldata _inputAndOutput,
        bool _isBefore
    ) internal {
        if (_isBefore) revert ShareTokenBeforeForbidden();

        (
            address sender,
            address recipient,
            uint256 amount,
            uint256 senderBalance,
            uint256 recipientBalance,
            uint256 totalSupply
        ) = Hook.afterTokenTransferDecode(_inputAndOutput);

        if (_action.matchAction(Hook.shareTokenTransfer(Hook.COLLATERAL_TOKEN))) {
            emit ShareTokenAfterHA(
                _silo,
                sender,
                recipient,
                amount,
                senderBalance,
                recipientBalance,
                totalSupply,
                ISilo.CollateralType.Collateral
            );
        } else if (_action.matchAction(Hook.shareTokenTransfer(Hook.PROTECTED_TOKEN))) {
            emit ShareTokenAfterHA(
                _silo,
                sender,
                recipient,
                amount,
                senderBalance,
                recipientBalance,
                totalSupply,
                ISilo.CollateralType.Protected
            );
        }
    }

    function _processWithdraw(address _silo, uint256 _action, bytes calldata _inputAndOutput, bool _isBefore) internal {
        bool isCollateral = _action.matchAction(Hook.withdrawAction(ISilo.CollateralType.Collateral));

        ISilo.CollateralType collateralType = isCollateral
                ? ISilo.CollateralType.Collateral
                : ISilo.CollateralType.Protected;

        if (_isBefore) {
            Hook.BeforeWithdrawInput memory input = Hook.beforeWithdrawDecode(_inputAndOutput);

            emit WithdrawBeforeHA(
                _silo,
                input.assets,
                input.shares,
                input.receiver,
                input.owner,
                input.spender,
                collateralType
            );
        } else {
            Hook.AfterWithdrawInput memory input = Hook.afterWithdrawDecode(_inputAndOutput);

            emit WithdrawAfterHA(
                _silo,
                input.assets,
                input.shares,
                input.receiver,
                input.owner,
                input.spender,
                input.withdrawnAssets,
                input.withdrawnShares,
                collateralType
            );
        }
    }
}
