// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ClonesUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/ClonesUpgradeable.sol";

import {IHookReceiversFactory} from "../interfaces/IHookReceiversFactory.sol";

/// @notice Utility contract to clone multiple copies in a single transaction
contract HookReceiversFactory is IHookReceiversFactory {
    /// @inheritdoc IHookReceiversFactory
    function clone(RequiredHookReceivers memory _required)
        external
        returns (CreatedHookReceivers memory clones)
    {
        if (_required.protectedHookReceiver0 != address(0)) {
            clones.protectedHookReceiver0 = ClonesUpgradeable.clone(_required.protectedHookReceiver0);
        }

        if (_required.collateralHookReceiver0 != address(0)) {
            clones.collateralHookReceiver0 = ClonesUpgradeable.clone(_required.collateralHookReceiver0);
        }

        if (_required.debtHookReceiver0 != address(0)) {
            clones.debtHookReceiver0 = ClonesUpgradeable.clone(_required.debtHookReceiver0);
        }

        if (_required.protectedHookReceiver1 != address(0)) {
            clones.protectedHookReceiver1 = ClonesUpgradeable.clone(_required.protectedHookReceiver1);
        }

        if (_required.collateralHookReceiver1 != address(0)) {
            clones.collateralHookReceiver1 = ClonesUpgradeable.clone(_required.collateralHookReceiver1);
        }

        if (_required.debtHookReceiver1 != address(0)) {
            clones.debtHookReceiver1 = ClonesUpgradeable.clone(_required.debtHookReceiver1);
        }
    }
}
