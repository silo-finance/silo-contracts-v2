// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

/// @notice Utility contract to clone all required hook receivers in a single transaction
interface IHookReceiversFactory {
    /// @notice Hook receiver to be cloned
    struct RequiredHookReceivers {
        address protectedHookReceiver0;
        address collateralHookReceiver0;
        address debtHookReceiver0;
        address protectedHookReceiver1;
        address collateralHookReceiver1;
        address debtHookReceiver1;
    }

    /// @notice Clones of the required hook receivers
    struct CreatedHookReceivers {
        address protectedHookReceiver0;
        address collateralHookReceiver0;
        address debtHookReceiver0;
        address protectedHookReceiver1;
        address collateralHookReceiver1;
        address debtHookReceiver1;
    }

    /// @notice Create multiple clones
    /// @param _required Required implementations to be cloned
    /// @param clones Clones of the required implementations
    function clone(RequiredHookReceivers memory _required)
        external
        returns (CreatedHookReceivers memory clones);
}
