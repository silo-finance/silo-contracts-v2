// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {Initializable} from "openzeppelin5/proxy/utils/Initializable.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {HookActionDataDecoder} from "../lib/HookActionDataDecoder.sol";
import {IGaugeLike as IGauge} from "./interfaces/IGaugeLike.sol";
import {IGaugeHookReceiver, IHookReceiver} from "./interfaces/IGaugeHookReceiver.sol";
import {SiloHookReceiver} from "../_common/SiloHookReceiver.sol";

/// @notice Silo share token hook receiver for the gauge.
/// It notifies the gauge (if configured) about any balance update in the Silo share token.
contract GaugeHookReceiver is IGaugeHookReceiver, SiloHookReceiver, Ownable2Step, Initializable {
    using Hook for uint256;
    using Hook for uint24;

    uint256 internal constant HOOKS_BEFORE_NOT_CONFIGURED = 0;

    IGauge public gauge;
    IShareToken public shareToken;
    ISiloConfig public siloConfig;

    mapping(IShareToken => IGauge) public configuredGauges;

    constructor() Ownable(msg.sender) {
        _disableInitializers();
        _transferOwnership(address(0));
    }

    /// @notice Initialize a hook receiver
    /// @param _owner Owner of the hook receiver (DAO)
    function initialize(address _owner, ISiloConfig _siloConfig) external virtual initializer {
        if (_owner == address(0)) revert OwnerIsZeroAddress();
        if (address(_siloConfig) == address(0)) revert EmptySiloConfig();

        siloConfig = _siloConfig;
        _transferOwnership(_owner);
    }

    /// @inheritdoc IGaugeHookReceiver
    function setGauge(IGauge _gauge) external virtual onlyOwner {
        IShareToken _shareToken = IShareToken(_gauge.share_token());
        IGauge configuredGauge = configuredGauges[_shareToken];

        if (address(configuredGauge) == address(0) && address(_gauge) == address(0)) revert GaugeIsNotConfigured();
        if (address(configuredGauge) != address(0) && !configuredGauge.is_killed()) revert CantUpdateActiveGauge();

        address silo = _shareToken.silo();

        uint24 tokenType = _getTokenType(silo, address(_shareToken));
        uint24 hooksAfter = _getHooksAfter(silo);

        if (configuredGauge == address(0)) {
            // If gauge was not configured before we add action to the hooksAfter
            uint24 action = tokenType | Hook.SHARE_TOKEN_TRANSFER;
            hooksAfter = hooksAfter.addAction(action);
        } else if (address(_gauge) == address(0)) {
            // if provided gauge is zero address we remove action from the hooksAfter
            hooksAfter = hooksAfter.removeAction(tokenType);
        }

        _setHookConfig(silo, HOOKS_BEFORE_NOT_CONFIGURED, hooksAfter);

        configuredGauges[_shareToken] = _gauge;

        emit GaugeConfigured(address(gauge), address(_shareToken));
    }

    function beforeAction(address, uint256, bytes calldata) external {
        // Do not expect any actions.
        revert RequestNotSupported();
    }

    function afterAction(address _silo, uint256 _action, bytes calldata _inputAndOutput) external {
        IGauge theGauge = configuredGauges[msg.sender];

        if (theGauge == IGauge(address(0))) revert GaugeIsNotConfigured();

        if (theGauge.is_killed()) return; // Do not revert if gauge is killed. Ignore the action.
        if (_getHooksAfter(silo).matchAction(_action)) return; // Should not happen, but just in case

        (
            address sender,
            address recipient,
            /* uint256 amount */,
            uint256 senderBalance,
            uint256 recipientBalance,
            uint256 totalSupply
        ) = _encodedParams.afterTokenTransferDecode();

        theGauge.afterTokenTransfer(
            sender,
            senderBalance,
            recipient,
            recipientBalance,
            totalSupply
        );
    }

    function _getTokenType(address _silo, address _shareToken) internal view returns (uint24) {
        (
            address protectedShareToken,
            address collateralShareToken,
            address debtShareToken
        ) = siloConfig.shareTokens(_silo);

        if (_shareToken == collateralShareToken) return uint24(Hook.SHARE_TOKEN_COLLATERAL);
        if (_shareToken == protectedShareToken) return uint24(Hook.SHARE_TOKEN_PROTECTED);
        if (_shareToken == debtShareToken) return uint24(Hook.SHARE_TOKEN_DEBT);

        revert InvalidShareToken();
    }
}
