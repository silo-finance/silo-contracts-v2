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
    using Hook for uint256;

    IGauge public gauge;
    IShareToken public shareToken;

    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize a hook receiver
    /// @param _owner Owner of the hook receiver (DAO)
    /// @param _token Silo share token for which hook receiver should be initialized.
    function initialize(address _owner, IShareToken _token) external virtual initializer {
        if (_owner == address(0)) revert OwnerIsZeroAddress();
        if (_token.hookSetup().hookReceiver != address(this)) revert InvalidShareToken();

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

    function beforeAction(address _silo, uint256 _action, bytes calldata _input)
        external
        returns (uint256 hookReturnCode)
    {
        // TODO
    }

    function afterAction(address _silo, uint256 _action, bytes calldata _inputAndOutput)
        external
        returns (uint256 hookReturnCode)
    {
        if (_action.matchAction(Hook.SHARE_TOKEN_TRANSFER)) return Hook.RETURN_CODE_SUCCESS;

        (
            address sender,
            address recipient,
            uint256 amount,
            uint256 senderBalance,
            uint256 recipientBalance,
            uint256 totalSupply
        ) = abi.decode(_inputAndOutput, (address, address, uint256, uint256, uint256, uint256));

        if (msg.sender != address(shareToken)) revert Unauthorized();

        IGauge theGauge = gauge;

        if (address(theGauge) == address(0) || theGauge.is_killed()) return Hook.RETURN_CODE_SUCCESS;

        theGauge.afterTokenTransfer(
            sender,
            senderBalance,
            recipient,
            recipientBalance,
            totalSupply
        );
    }
}
