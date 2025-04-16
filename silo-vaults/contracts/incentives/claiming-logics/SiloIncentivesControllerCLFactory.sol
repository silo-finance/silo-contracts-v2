// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Create2Factory} from "common/utils/Create2Factory.sol";
import {ISiloIncentivesControllerCLFactory} from "../../interfaces/ISiloIncentivesControllerCLFactory.sol";
import {SiloIncentivesControllerCL} from "./SiloIncentivesControllerCL.sol";

/// @dev Factory for creating SiloIncentivesControllerCL instances
contract SiloIncentivesControllerCLFactory is Create2Factory, ISiloIncentivesControllerCLFactory {
    mapping(address => bool) public createdInFactory;

    /// @inheritdoc ISiloIncentivesControllerCLFactory
    function createIncentivesControllerCL(
        address _vaultIncentivesController,
        address _siloIncentivesController,
        bytes32 _externalSalt
    ) external returns (SiloIncentivesControllerCL logic) {
        logic = new SiloIncentivesControllerCL{salt: _salt(_externalSalt)}(
            _vaultIncentivesController,
            _siloIncentivesController
        );

        createdInFactory[address(logic)] = true;

        emit IncentivesControllerCLCreated(address(logic));
    }
}
