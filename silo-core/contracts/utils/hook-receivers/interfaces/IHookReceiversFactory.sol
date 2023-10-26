// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

/// @notice Utility contract to clone all required hook receivers in a single transaction
interface IHookReceiversFactory {
    /// @notice Silo hook receivers
    struct HookReceivers {
        address protectedHookReceiver0;
        address collateralHookReceiver0;
        address debtHookReceiver0;
        address protectedHookReceiver1;
        address collateralHookReceiver1;
        address debtHookReceiver1;
    }

    /// @notice Create multiple clones
    /// @param _implementation Required implementations to be cloned
    /// @param clones Clones of the required implementations
    function create(HookReceivers memory _implementation)
        external
        returns (HookReceivers memory clones);
}
