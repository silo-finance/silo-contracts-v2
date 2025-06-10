// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Create2Factory} from "common/utils/Create2Factory.sol";

import {SiloIncentivesController} from "./SiloIncentivesController.sol";
import {ISiloIncentivesControllerFactory} from "./interfaces/ISiloIncentivesControllerFactory.sol";

/// @title SiloIncentivesControllerFactory
/// @notice Factory contract for creating SiloIncentivesController instances.
contract SiloIncentivesControllerFactory is Create2Factory, ISiloIncentivesControllerFactory {
    mapping(address => bool) public isSiloIncentivesController;

    /// @inheritdoc ISiloIncentivesControllerFactory
    function create(
        address _owner,
        address _notifier,
        address _shareToken,
        bytes32 _externalSalt
    ) external returns (address controller) {
        controller = address(new SiloIncentivesController{salt: _salt(_externalSalt)}(_owner, _notifier, _shareToken));

        isSiloIncentivesController[controller] = true;

        emit SiloIncentivesControllerCreated(controller);
    }
}
