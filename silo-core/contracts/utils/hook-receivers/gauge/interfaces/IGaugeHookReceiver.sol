// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IHookReceiver} from "../../interfaces/IHookReceiver.sol";
import {IGaugeLike as IGauge} from "./IGaugeLike.sol";

/// @notice Silo share token hook receiver for the gauge
interface IGaugeHookReceiver is IHookReceiver {
    /// @dev Emit when the new gauge is configured
    /// @param gauge Gauge for which hook receiver will send notification about the share token balance updates.
    event GaugeConfigured(address gauge);

    /// @dev Revert if other than `shareToken` address call `afterTokenTransfer` fn
    error Unauthorized();
    /// @dev Revert on an attempt to inialize with a zero `_owner` address
    error OwnerIsZeroAddress();
    /// @dev Revert on an attempt to initialize with an invalid `_shareToken` address
    error InvalidShareToken();
    /// @dev Revert on an attempt to setup a `_gauge` with a different `_shareToken`
    /// than hook receiver were initialized
    error WrongGaugeShareToken();
    /// @dev Revert on an attempt to update a `gauge` that still can mint SILO tokens
    error CantUpdateActiveGauge();
    /// @dev Revert if the gauge hook receiver already has a configured gauge
    error AlreadyConfigured();

    /// @notice Initialize a hook receiver
    /// @param _owner Owner of the hook receiver (DAO)
    /// @param _token Silo share token for which hook receiver should be initialized.
    /// It should be a silo collateral token, protected share token, or debt share token.
    /// If any additional data is needed for the hook receiver initialization,
    /// it can be resolved from the silo, which can be resolved from the share token.
    function initialize(address _owner, IShareToken _token) external;

    /// @notice Configuration of the gauge
    /// for which the hook receiver should send notifications about the share token balance updates.
    /// The `_gauge` can be updated by an owner (DAO)
    /// @param _gauge Gauge that should receive notifications
    function setGauge(IGauge _gauge) external;

    function gauge() external view returns (IGauge);
    function shareToken() external view returns (IShareToken);
}
