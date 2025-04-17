// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SiloIncentivesControllerCL} from "../incentives/claiming-logics/SiloIncentivesControllerCL.sol";

/// @title ISiloIncentivesControllerCLFactory
interface ISiloIncentivesControllerCLFactory {
    /// @notice Emitted when a new SiloIncentivesControllerCL instance is created
    event IncentivesControllerCLCreated(address logic);

    /// @notice Creates a new SiloIncentivesControllerCL instance
    /// @param _vaultIncentivesController The address of the vault incentives controller
    /// @param _siloIncentivesController The address of the silo incentives controller
    /// @param _externalSalt The external salt to use for the creation of the SiloIncentivesControllerCL instance
    /// @return logic The address of the created SiloIncentivesControllerCL instance
    function createIncentivesControllerCL(
        address _vaultIncentivesController,
        address _siloIncentivesController,
        bytes32 _externalSalt
    ) external returns (SiloIncentivesControllerCL logic);

    /// @notice Checks if a SiloIncentivesControllerCL instance is created in the factory
    /// @param _logic The address of the SiloIncentivesControllerCL instance
    /// @return createdInFactory Whether the SiloIncentivesControllerCL instance is created in the factory
    function createdInFactory(address _logic) external view returns (bool createdInFactory);
}
