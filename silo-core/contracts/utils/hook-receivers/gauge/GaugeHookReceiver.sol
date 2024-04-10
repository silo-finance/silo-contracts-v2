// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Ownable2StepUpgradeable} from "openzeppelin-contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IGaugeLike as IGauge} from "./interfaces/IGaugeLike.sol";
import {IGaugeHookReceiver, IHookReceiver} from "./interfaces/IGaugeHookReceiver.sol";
import {Hook} from "../../../lib/Hook.sol";

/// @notice Silo share token hook receiver for the gauge.
/// It notifies the gauge (if configured) about any balance update in the Silo share token.
contract GaugeHookReceiver is IGaugeHookReceiver, Ownable2StepUpgradeable {
    IGauge public gauge;
    IShareToken public shareToken;

    constructor() {
        _disableInitializers();
    }

    // TODO why there is no .initialize() call in any place for this gauge?
    /// @notice Initialize a hook receiver
    /// @param _owner Owner of the hook receiver (DAO)
    /// @param _token Silo share token for which hook receiver should be initialized.
    /// It should be a silo collateral token, protected share token, or debt share token.
    /// If any additional data is needed for the hook receiver initialization,
    /// it can be resolved from the silo, which can be resolved from the share token.
    function initialize(address _owner, IShareToken _token) external virtual initializer {
        if (_owner == address(0)) revert OwnerIsZeroAddress();
        if (_token.hookReceiver() != address(this)) revert InvalidShareToken();

        _transferOwnership(_owner);

        shareToken = _token;
    }

    /// @inheritdoc IGaugeHookReceiver
    function setGauge(IGauge _gauge) external virtual onlyOwner {
        if (address(gauge) != address(0) && !gauge.is_killed()) revert CantUpdateActiveGauge();
        if (_gauge.share_token() != address(shareToken)) revert WrongGaugeShareToken();

        gauge = _gauge;

        emit GaugeConfigured(address(gauge));
    }

    /// @inheritdoc IHookReceiver
    function afterTokenTransfer(
        address _sender,
        uint256 _senderBalance,
        address _recipient,
        uint256 _recipientBalance,
        uint256 _totalSupply,
        uint256 /* _amount */
    ) external virtual returns (uint256 hookReturnCode) {
        if (msg.sender != address(shareToken)) revert Unauthorized();

        IGauge theGauge = gauge;

        if (address(theGauge) == address(0) || theGauge.is_killed()) return Hook.RETURN_CODE_SUCCESS;

        theGauge.afterTokenTransfer(
            _sender,
            _senderBalance,
            _recipient,
            _recipientBalance,
            _totalSupply
        );
    }
}
