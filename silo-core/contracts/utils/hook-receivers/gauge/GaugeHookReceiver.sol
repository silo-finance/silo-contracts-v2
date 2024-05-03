// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {Initializable} from "openzeppelin5/proxy/utils/Initializable.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IGaugeLike as IGauge} from "./interfaces/IGaugeLike.sol";
import {IGaugeHookReceiver, IHookReceiver} from "./interfaces/IGaugeHookReceiver.sol";
import {SiloHookReceiver} from "../_common/SiloHookReceiver.sol";
import {Hook} from "../../../lib/Hook.sol";

/// @notice Silo share token hook receiver for the gauge.
/// It notifies the gauge (if configured) about any balance update in the Silo share token.
contract GaugeHookReceiver is IGaugeHookReceiver, SiloHookReceiver, Ownable2Step, Initializable {
    using Hook for uint256;

    IGauge public gauge;
    IShareToken public shareToken;

    constructor() Ownable(msg.sender) {
        _disableInitializers();
    }

    /// @notice Initialize a hook receiver
    /// @param _owner Owner of the hook receiver (DAO)
    function initialize(address _owner, ISiloConfig /* siloConfig */) external virtual initializer {
        if (_owner == address(0)) revert OwnerIsZeroAddress();

        _transferOwnership(_owner);
    }

    /// @inheritdoc IGaugeHookReceiver
    function setGauge(IGauge _gauge) external virtual onlyOwner {
        if (address(gauge) != address(0) && !gauge.is_killed()) revert CantUpdateActiveGauge();
        if (_gauge.share_token() != address(shareToken)) revert WrongGaugeShareToken();

        gauge = _gauge;

        emit GaugeConfigured(address(gauge));
    }

    function beforeAction(address /* _silo */, uint256 /* _action */, bytes calldata /* _input */) external {
        // TODO
    }

    function afterAction(address /* _silo */, uint256 _action, bytes calldata _inputAndOutput) external {
        if (_action.matchAction(Hook.SHARE_TOKEN_TRANSFER)) return;

        (
            address sender,
            address recipient,
            /* uint256 amount */,
            uint256 senderBalance,
            uint256 recipientBalance,
            uint256 totalSupply
        ) = abi.decode(_inputAndOutput, (address, address, uint256, uint256, uint256, uint256));

        if (msg.sender != address(shareToken)) revert Unauthorized();

        IGauge theGauge = gauge;

        if (address(theGauge) == address(0) || theGauge.is_killed()) return;

        theGauge.afterTokenTransfer(
            sender,
            senderBalance,
            recipient,
            recipientBalance,
            totalSupply
        );
    }
}
