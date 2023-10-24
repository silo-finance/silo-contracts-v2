// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ClonesUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/ClonesUpgradeable.sol";

import {IHookReceiversFactory} from "./interfaces/IHookReceiversFactory.sol";

/// @notice Utility contract to clone multiple copies in a single transaction
contract HookReceiversFactory is IHookReceiversFactory {
    /// @inheritdoc IHookReceiversFactory
    function create(HookReceivers memory _implementation)
        external
        returns (HookReceivers memory clones)
    {
        if (_implementation.protectedHookReceiver0 != address(0)) {
            clones.protectedHookReceiver0 = ClonesUpgradeable.clone(_implementation.protectedHookReceiver0);
        }

        if (_implementation.collateralHookReceiver0 != address(0)) {
            clones.collateralHookReceiver0 = ClonesUpgradeable.clone(_implementation.collateralHookReceiver0);
        }

        if (_implementation.debtHookReceiver0 != address(0)) {
            clones.debtHookReceiver0 = ClonesUpgradeable.clone(_implementation.debtHookReceiver0);
        }

        if (_implementation.protectedHookReceiver1 != address(0)) {
            clones.protectedHookReceiver1 = ClonesUpgradeable.clone(_implementation.protectedHookReceiver1);
        }

        if (_implementation.collateralHookReceiver1 != address(0)) {
            clones.collateralHookReceiver1 = ClonesUpgradeable.clone(_implementation.collateralHookReceiver1);
        }

        if (_implementation.debtHookReceiver1 != address(0)) {
            clones.debtHookReceiver1 = ClonesUpgradeable.clone(_implementation.debtHookReceiver1);
        }
    }
}
