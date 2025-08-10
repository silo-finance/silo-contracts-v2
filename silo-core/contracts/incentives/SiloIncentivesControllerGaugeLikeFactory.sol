// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Create2Factory} from "common/utils/Create2Factory.sol";
import {SiloIncentivesControllerGaugeLike} from "./SiloIncentivesControllerGaugeLike.sol";
import {ISiloIncentivesControllerGaugeLikeFactory} from "./interfaces/ISiloIncentivesControllerGaugeLikeFactory.sol";

/// @dev Factory for creating SiloIncentivesControllerGaugeLike instances
contract SiloIncentivesControllerGaugeLikeFactory is Create2Factory,ISiloIncentivesControllerGaugeLikeFactory {
    mapping(address => bool) public createdInFactory;

    /// @inheritdoc ISiloIncentivesControllerGaugeLikeFactory
    function createGaugeLike(
        address _owner,
        address _notifier,
        address _shareToken,
        bytes32 _externalSalt
    ) external returns (address gaugeLike) {
        gaugeLike = address(
            new SiloIncentivesControllerGaugeLike{salt: _salt(_externalSalt)}(_owner, _notifier, _shareToken)
        );

        createdInFactory[gaugeLike] = true;

        emit GaugeLikeCreated(gaugeLike);
    }
}
