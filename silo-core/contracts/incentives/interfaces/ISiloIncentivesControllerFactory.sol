// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

interface ISiloIncentivesControllerFactory {
    event SiloIncentivesControllerCreated(address indexed controller);

    /// @notice Creates a new SiloIncentivesController instance.
    /// @param _owner The address of the owner of the SiloIncentivesController.
    /// @param _notifier The address of the notifier of the SiloIncentivesController.
    /// @param _externalSalt The external salt to use for the creation of the SiloIncentivesController instance.
    /// @return The address of the newly created SiloIncentivesController.
    function create(
        address _owner,
        address _notifier,
        address _shareToken,
        bytes32 _externalSalt
    ) external returns (address);

    /// @notice Checks if a given address is a SiloIncentivesController.
    /// @param _controller The address to check.
    /// @return True if the address is a SiloIncentivesController, false otherwise.
    function isSiloIncentivesController(address _controller) external view returns (bool);
}
