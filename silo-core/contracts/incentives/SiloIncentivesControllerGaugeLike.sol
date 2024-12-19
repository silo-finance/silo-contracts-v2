// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IGaugeLike} from "../interfaces/IGaugeLike.sol";
import {SiloIncentivesController} from "./SiloIncentivesController.sol";
import {ISiloIncentivesControllerGaugeLike} from "./interfaces/ISiloIncentivesControllerGaugeLike.sol";

/// @dev Silo incentives controller that can be used as a gauge in the Gauge hook receiver
contract SiloIncentivesControllerGaugeLike is SiloIncentivesController, ISiloIncentivesControllerGaugeLike {
    /// @dev The share token of the gauge
    address public immutable SHARE_TOKEN;

    /// @dev Whether the gauge is killed
    bool private _isKilled;

    /// @param _owner The owner of the gauge
    /// @param _notifier The notifier of the gauge
    /// @param _shareToken The share token of the gauge
    constructor(address _owner, address _notifier, address _shareToken) SiloIncentivesController(_owner, _notifier) {
        SHARE_TOKEN = _shareToken;
    }

    /// @inheritdoc ISiloIncentivesControllerGaugeLike
    function killGauge() external virtual onlyOwner {
        _isKilled = true;
        emit GaugeKilled();
    }

    /// @inheritdoc ISiloIncentivesControllerGaugeLike
    function unkillGauge() external virtual onlyOwner {
        _isKilled = false;
        emit GaugeUnkilled();
    }

    /// @inheritdoc ISiloIncentivesControllerGaugeLike
    // solhint-disable-next-line func-name-mixedcase
    function share_token() external view returns (address) {
        return SHARE_TOKEN;
    }

    /// @inheritdoc ISiloIncentivesControllerGaugeLike
    // solhint-disable-next-line func-name-mixedcase
    function is_killed() external view returns (bool) {
        return _isKilled;
    }
}
