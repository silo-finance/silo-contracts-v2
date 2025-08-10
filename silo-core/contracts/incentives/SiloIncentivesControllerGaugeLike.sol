// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SiloIncentivesController} from "./SiloIncentivesController.sol";
import {ISiloIncentivesController} from "./interfaces/ISiloIncentivesController.sol";

/// @dev Silo incentives controller that can be used as a gauge in the Gauge hook receiver
contract SiloIncentivesControllerGaugeLike is SiloIncentivesController {
    /// @notice Whether the gauge is killed
    /// @dev This flag is not used in the SiloIncentivesController,
    /// but it is used in the Gauge hook receiver (versions <= 3.7.0).
    bool internal _isKilled;

    event GaugeKilled();
    event GaugeUnKilled();

    /// @param _owner The owner of the incentives controller
    /// @param _notifier The notifier (expected to be a hook receiver address)
    /// @param _siloShareToken The share token that is incentivized
    constructor(
        address _owner,
        address _notifier,
        address _siloShareToken
    ) SiloIncentivesController(_owner, _notifier, _siloShareToken) {}

    function killGauge() external virtual onlyOwner {
        _isKilled = true;
        emit GaugeKilled();
    }

    function unkillGauge() external virtual onlyOwner {
        _isKilled = false;
        emit GaugeUnKilled();
    }

    // solhint-disable-next-line func-name-mixedcase
    function share_token() external view returns (address) {
        return SHARE_TOKEN;
    }

    // solhint-disable-next-line func-name-mixedcase
    function is_killed() external view returns (bool) {
        return _isKilled;
    }
}
