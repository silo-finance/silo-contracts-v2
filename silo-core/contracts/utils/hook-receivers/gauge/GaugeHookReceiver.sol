// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";

import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {IGaugeLike as IGauge} from "../../../interfaces/IGaugeLike.sol";
import {IGaugeHookReceiver, IHookReceiver} from "../../../interfaces/IGaugeHookReceiver.sol";
import {BaseHookReceiver} from "../_common/BaseHookReceiver.sol";

/// @notice Silo share token hook receiver for the gauge.
/// It notifies the gauge (if configured) about any balance update in the Silo share token.
abstract contract GaugeHookReceiver is BaseHookReceiver, IGaugeHookReceiver, Ownable2Step {
    using Hook for uint256;
    using Hook for bytes;

    uint24 internal constant _HOOKS_BEFORE_NOT_CONFIGURED = 0;

    mapping(IShareToken => IGauge) public configuredGauges;

    constructor() Ownable(msg.sender) {
        // lock implementation
        _transferOwnership(address(0));
    }

    /// @inheritdoc IGaugeHookReceiver
    function setGauge(IGauge _gauge, IShareToken _shareToken) external virtual onlyOwner {
        require(address(_gauge) != address(0), EmptyGaugeAddress());
        require(_gauge.share_token() == address(_shareToken), WrongGaugeShareToken());

        address configuredGauge = address(configuredGauges[_shareToken]);

        require(configuredGauge == address(0), GaugeAlreadyConfigured());

        address silo = address(_shareToken.silo());

        uint256 tokenType = _getTokenType(silo, address(_shareToken));
        uint256 hooksAfter = _getHooksAfter(silo);

        uint256 action = tokenType | Hook.SHARE_TOKEN_TRANSFER;
        hooksAfter = hooksAfter.addAction(action);

        _setHookConfig(silo, _HOOKS_BEFORE_NOT_CONFIGURED, hooksAfter);

        configuredGauges[_shareToken] = _gauge;

        emit GaugeConfigured(address(_gauge), address(_shareToken));
    }

    /// @inheritdoc IGaugeHookReceiver
    function removeGauge(IShareToken _shareToken) external virtual onlyOwner {
        IGauge configuredGauge = configuredGauges[_shareToken];

        require(address(configuredGauge) != address(0), GaugeIsNotConfigured());
        require(configuredGauge.is_killed(), CantRemoveActiveGauge());

        address silo = address(_shareToken.silo());
        
        uint256 tokenType = _getTokenType(silo, address(_shareToken));
        uint256 hooksAfter = _getHooksAfter(silo);

        hooksAfter = hooksAfter.removeAction(tokenType);

        _setHookConfig(silo, _HOOKS_BEFORE_NOT_CONFIGURED, hooksAfter);

        delete configuredGauges[_shareToken];

        emit GaugeRemoved(address(_shareToken));
    }

    /// @inheritdoc IHookReceiver
    function afterAction(address _silo, uint256 _action, bytes calldata _inputAndOutput)
        public
        virtual
        override
    {
        IGauge theGauge = configuredGauges[IShareToken(msg.sender)];

        require(theGauge != IGauge(address(0)), GaugeIsNotConfigured());

        if (theGauge.is_killed()) return; // Do not revert if gauge is killed. Ignore the action.
        if (!_getHooksAfter(_silo).matchAction(_action)) return; // Should not happen, but just in case

        Hook.AfterTokenTransfer memory input = _inputAndOutput.afterTokenTransferDecode();

        theGauge.afterTokenTransfer(
            input.sender,
            input.senderBalance,
            input.recipient,
            input.recipientBalance,
            input.totalSupply,
            input.amount
        );
    }

    /// @notice Get the token type for the share token
    /// @param _silo Silo address for which tokens was deployed
    /// @param _shareToken Share token address
    /// @dev Revert if wrong silo
    /// @dev Revert if the share token is not one of the collateral, protected or debt tokens
    function _getTokenType(address _silo, address _shareToken) internal view virtual returns (uint256) {
        (
            address protectedShareToken,
            address collateralShareToken,
            address debtShareToken
        ) = siloConfig.getShareTokens(_silo);

        if (_shareToken == collateralShareToken) return Hook.COLLATERAL_TOKEN;
        if (_shareToken == protectedShareToken) return Hook.PROTECTED_TOKEN;
        if (_shareToken == debtShareToken) return Hook.DEBT_TOKEN;

        revert InvalidShareToken();
    }

    /// @notice Set the owner of the hook receiver
    /// @param _owner Owner address
    function __GaugeHookReceiver_init(address _owner)
        internal
        onlyInitializing
        virtual
    {
        require(_owner != address(0), OwnerIsZeroAddress());

        _transferOwnership(_owner);
    }
}
