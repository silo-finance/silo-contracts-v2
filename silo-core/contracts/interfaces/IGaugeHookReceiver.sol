// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IShareToken} from "./IShareToken.sol";
import {IHookReceiver} from "./IHookReceiver.sol";
import {ISiloIncentivesController} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";

/// @notice Silo share token hook receiver for the gauge
interface IGaugeHookReceiver is IHookReceiver {
    /// @dev Emit when the new gauge is configured
    /// @param gauge Gauge for which hook receiver will send notification about the share token balance updates.
    /// @param shareToken Share token.
    event GaugeConfigured(address gauge, address shareToken);
    /// @dev Emit when the gauge is removed
    /// @param shareToken Share token for which the gauge was removed
    event GaugeRemoved(address shareToken);

    /// @dev Revert on an attempt to initialize with a zero `_owner` address
    error OwnerIsZeroAddress();
    /// @dev Revert on an attempt to initialize with an invalid `_shareToken` address
    error InvalidShareToken();
    /// @dev Revert on an attempt to setup a `_gauge` with a different `_shareToken`
    /// than hook receiver were initialized
    error WrongGaugeShareToken();
    /// @dev Revert on an attempt to remove a `gauge` that still can mint SILO tokens
    error CantRemoveActiveGauge();
    /// @dev Revert on an attempt to set a gauge with a zero address
    error EmptyGaugeAddress();
    /// @dev Revert if the hook received `beforeAction` notification
    error RequestNotSupported();
    /// @dev Revert on an attempt to remove not configured gauge
    error GaugeIsNotConfigured();
    /// @dev Revert on an attempt to configure already configured gauge
    error GaugeAlreadyConfigured();

    /// @notice Configuration of the gauge
    /// for which the hook receiver should send notifications about the share token balance updates.
    /// The `_gauge` can be updated by an owner (DAO)
    /// @dev Overrides existing configuration
    /// @param _shareToken Share token for which the gauge is configured
    /// @param _gauge Array of gauges for which hook receiver will send notification.
    function setGauge(ISiloIncentivesController _gauge, IShareToken _shareToken) external;

    /// @notice Remove the gauge from the hook receiver for the share token
    /// @dev While removing the gauge,
    /// we do not remove the action because we don't know if any other hook is using it.
    /// @param _shareToken Share token for which the gauge needs to be removed
    function removeGauge(IShareToken _shareToken) external;

    /// @notice Get the gauge for the share token
    /// @param _shareToken Share token
    function configuredGauges(IShareToken _shareToken) external view returns (ISiloIncentivesController);
}
