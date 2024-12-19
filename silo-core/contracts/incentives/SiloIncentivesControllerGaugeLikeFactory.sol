// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SiloIncentivesControllerGaugeLike} from "./SiloIncentivesControllerGaugeLike.sol";
import {ISiloIncentivesControllerGaugeLikeFactory} from "./interfaces/ISiloIncentivesControllerGaugeLikeFactory.sol";

/// @dev Factory for creating SiloIncentivesControllerGaugeLike instances
contract SiloIncentivesControllerGaugeLikeFactory is ISiloIncentivesControllerGaugeLikeFactory {
    mapping(address => bool) public createdInFactory;

    /// @inheritdoc ISiloIncentivesControllerGaugeLikeFactory
    function createGaugeLike(
        address _owner,
        address _notifier,
        address _shareToken
    ) external returns (address gaugeLike) {
        gaugeLike = address(new SiloIncentivesControllerGaugeLike(_owner, _notifier, _shareToken));

        createdInFactory[gaugeLike] = true;

        emit GaugeLikeCreated(gaugeLike);
    }
}
