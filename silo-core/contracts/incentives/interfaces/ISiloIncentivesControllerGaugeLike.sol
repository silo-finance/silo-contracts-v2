// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.28;

/// @dev Interface for the SiloIncentivesControllerGaugeLike contract
/// @notice Implements function to make the silo incentives controller gauge like
interface ISiloIncentivesControllerGaugeLike {
    event GaugeKilled();
    event GaugeUnkilled();

    /// @notice Kills the gauge
    function killGauge() external;

    /// @notice Unkills the gauge
    function unkillGauge() external;

    /// @dev The share token of the gauge
    function share_token() external view returns (address);

    /// @dev Whether the gauge is killed
    function is_killed() external view returns (bool);
}
