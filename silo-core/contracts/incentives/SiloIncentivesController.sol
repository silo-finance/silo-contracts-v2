// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SiloIncentivesControllerBase} from "./SiloIncentivesControllerBase.sol";
import {IBackwardsCompatibleGaugeLike} from "./interfaces/IBackwardsCompatibleGaugeLike.sol";

/// @dev Silo incentives controller that can be used as a gauge in the Gauge hook receiver
contract SiloIncentivesController is SiloIncentivesControllerBase, IBackwardsCompatibleGaugeLike {
    /// @notice Whether the gauge is killed
    /// @dev This flag is not used in the SiloIncentivesController,
    /// but it is used in the Gauge hook receiver (versions <= 3.7.0).
    bool internal _isKilled;

    event GaugeKilled();
    event GaugeUnKilled();

    constructor(address _owner, address _notifier, address _shareTokenAddress)
        SiloIncentivesControllerBase(_owner, _notifier, _shareTokenAddress) 
    {
    }

    function afterTokenTransfer(
        address _sender,
        uint256 _senderBalance,
        address _recipient,
        uint256 _recipientBalance,
        uint256 _totalSupply,
        uint256 _amount
    ) public virtual override(IBackwardsCompatibleGaugeLike, SiloIncentivesControllerBase) {
        super.afterTokenTransfer(_sender, _senderBalance, _recipient, _recipientBalance, _totalSupply, _amount);
    }

    function killGauge() external virtual {
        _isKilled = true;
        emit GaugeKilled();
    }

    function unkillGauge() external virtual {
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
