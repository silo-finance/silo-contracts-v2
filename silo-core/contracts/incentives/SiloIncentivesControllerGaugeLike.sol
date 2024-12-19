// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {IGaugeLike as IGauge} from "../interfaces/IGaugeLike.sol";
import {SiloIncentivesController} from "./SiloIncentivesController.sol";
import {ISiloIncentivesController} from "./interfaces/ISiloIncentivesController.sol";

/// @dev Silo incentives controller that can be used as a gauge in the Gauge hook receiver
contract SiloIncentivesControllerGaugeLike is SiloIncentivesController, IGauge {
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

    /// @inheritdoc ISiloIncentivesController
    function afterTokenTransfer(
        address _sender,
        uint256 _senderBalance,
        address _recipient,
        uint256 _recipientBalance,
        uint256 _totalSupply,
        uint256 _amount
    )
        public
        virtual
        override(SiloIncentivesController, IGauge)
        onlyNotifier
    {
        SiloIncentivesController.afterTokenTransfer(
            _sender, _senderBalance, _recipient, _recipientBalance, _totalSupply, _amount
        );
    }

    /// @inheritdoc IGauge
    function killGauge() external virtual onlyOwner {
        _isKilled = true;
        emit GaugeKilled();
    }

    /// @inheritdoc IGauge
    function unkillGauge() external virtual onlyOwner {
        _isKilled = false;
        emit GaugeUnKilled();
    }

    /// @inheritdoc IGauge
    // solhint-disable-next-line func-name-mixedcase
    function share_token() external view returns (address) {
        return SHARE_TOKEN;
    }

    /// @inheritdoc IGauge
    // solhint-disable-next-line func-name-mixedcase
    function is_killed() external view returns (bool) {
        return _isKilled;
    }

    function _shareToken() internal view override returns (IERC20 shareToken) {
        shareToken = IERC20(SHARE_TOKEN);
    }
}