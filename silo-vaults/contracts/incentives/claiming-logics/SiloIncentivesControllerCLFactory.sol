// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISiloIncentivesControllerCLFactory} from "../../interfaces/ISiloIncentivesControllerCLFactory.sol";
import {SiloIncentivesControllerCL} from "./SiloIncentivesControllerCL.sol";

/// @dev Factory for creating SiloIncentivesControllerCL instances
contract SiloIncentivesControllerCLFactory is ISiloIncentivesControllerCLFactory {
    mapping(address => bool) public createdInFactory;

    /// @inheritdoc ISiloIncentivesControllerCLFactory
    function createIncentivesControllerCL(
        address _vaultIncentivesController,
        address _siloIncentivesController
    ) external returns (SiloIncentivesControllerCL logic) {
        logic = new SiloIncentivesControllerCL(_vaultIncentivesController, _siloIncentivesController);

        createdInFactory[address(logic)] = true;

        emit IncentivesControllerCLCreated(address(logic));
    }
}
