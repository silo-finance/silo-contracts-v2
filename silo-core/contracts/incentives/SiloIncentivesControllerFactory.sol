// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SiloIncentivesController} from "./SiloIncentivesController.sol";
import {ISiloIncentivesControllerFactory} from "./interfaces/ISiloIncentivesControllerFactory.sol";

/// @title SiloIncentivesControllerFactory
/// @notice Factory contract for creating SiloIncentivesController instances.
contract SiloIncentivesControllerFactory is ISiloIncentivesControllerFactory {
    mapping(address => bool) public isSiloIncentivesController;

    /// @inheritdoc ISiloIncentivesControllerFactory
    function create(address _owner, address _notifier) external returns (address controller) {
        controller = address(new SiloIncentivesController(_owner, _notifier));

        isSiloIncentivesController[controller] = true;

        emit SiloIncentivesControllerCreated(controller);
    }
}
