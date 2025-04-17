// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

interface ISiloIncentivesControllerGaugeLikeFactory {
    event GaugeLikeCreated(address gaugeLike);

    /// @dev Creates a new SiloIncentivesControllerGaugeLike instance
    /// @param _owner The owner of the gauge
    /// @param _notifier The notifier of the gauge
    /// @param _shareToken The share token of the gauge
    /// @return The address of the new SiloIncentivesControllerGaugeLike instance
    function createGaugeLike(address _owner, address _notifier, address _shareToken) external returns (address);

    /// @dev Whether the gauge like was created in the factory
    function createdInFactory(address _gaugeLike) external view returns (bool);
}
