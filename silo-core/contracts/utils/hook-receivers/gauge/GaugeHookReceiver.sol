// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {Initializable} from "openzeppelin5/proxy/utils/Initializable.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {PartialLiquidation} from "../liquidation/PartialLiquidation.sol";
import {IGaugeLike as IGauge} from "../../../interfaces/IGaugeLike.sol";
import {IGaugeHookReceiver, IHookReceiver} from "../../../interfaces/IGaugeHookReceiver.sol";
import {SiloHookReceiver} from "../_common/SiloHookReceiver.sol";

/// @notice Silo share token hook receiver for the gauge.
/// It notifies the gauge (if configured) about any balance update in the Silo share token.
contract GaugeHookReceiver is PartialLiquidation, IGaugeHookReceiver, SiloHookReceiver, Ownable2Step, Initializable {
    using Hook for uint256;
    using Hook for bytes;

    uint24 internal constant _HOOKS_BEFORE_NOT_CONFIGURED = 0;

    IGauge public gauge;
    IShareToken public shareToken;

    mapping(IShareToken => IGauge) public configuredGauges;

    constructor() Ownable(msg.sender) {
        _disableInitializers();
        _transferOwnership(address(0));
    }

    /// @inheritdoc IHookReceiver
    function initialize(ISiloConfig _siloConfig, bytes calldata _data)
        external
        virtual
        initializer
        override(IHookReceiver, PartialLiquidation)
    {
        (address owner) = abi.decode(_data, (address));

        if (owner == address(0)) revert OwnerIsZeroAddress();

        _initialize(_siloConfig);
        _transferOwnership(owner);
    }

    /// @inheritdoc IGaugeHookReceiver
    function setGauge(IGauge _gauge, IShareToken _shareToken) external virtual onlyOwner {
        if (address(_gauge) == address(0)) revert EmptyGaugeAddress();
        if (_gauge.share_token() != address(_shareToken)) revert WrongGaugeShareToken();

        address configuredGauge = address(configuredGauges[_shareToken]);

        if (configuredGauge != address(0)) revert GaugeAlreadyConfigured();

        address silo = address(_shareToken.silo());

        uint256 tokenType = _getTokenType(silo, address(_shareToken));
        uint256 hooksAfter = _getHooksAfter(silo);

        uint256 action = tokenType | Hook.SHARE_TOKEN_TRANSFER;
        hooksAfter = hooksAfter.addAction(action);

        _setHookConfig(silo, _HOOKS_BEFORE_NOT_CONFIGURED, hooksAfter);

        configuredGauges[_shareToken] = _gauge;

        emit GaugeConfigured(address(gauge), address(_shareToken));
    }

    /// @inheritdoc IGaugeHookReceiver
    function removeGauge(IShareToken _shareToken) external virtual onlyOwner {
        IGauge configuredGauge = configuredGauges[_shareToken];

        if (address(configuredGauge) == address(0)) revert GaugeIsNotConfigured();
        if (!configuredGauge.is_killed()) revert CantRemoveActiveGauge();

        address silo = address(_shareToken.silo());
        
        uint256 tokenType = _getTokenType(silo, address(_shareToken));
        uint256 hooksAfter = _getHooksAfter(silo);

        hooksAfter = hooksAfter.removeAction(tokenType);

        _setHookConfig(silo, _HOOKS_BEFORE_NOT_CONFIGURED, hooksAfter);

        delete configuredGauges[_shareToken];

        emit GaugeRemoved(address(_shareToken));
    }

    /// @inheritdoc IHookReceiver
    function beforeAction(address, uint256, bytes calldata)
        external
        virtual
        override(IHookReceiver, PartialLiquidation)
    {
        // Do not expect any actions.
        revert RequestNotSupported();
    }

    /// @inheritdoc IHookReceiver
    function afterAction(address _silo, uint256 _action, bytes calldata _inputAndOutput)
        external
        virtual
        override(IHookReceiver, PartialLiquidation)
    {
        IGauge theGauge = configuredGauges[IShareToken(msg.sender)];

        if (theGauge == IGauge(address(0))) revert GaugeIsNotConfigured();

        if (theGauge.is_killed()) return; // Do not revert if gauge is killed. Ignore the action.
        if (!_getHooksAfter(_silo).matchAction(_action)) return; // Should not happen, but just in case

        Hook.AfterTokenTransfer memory input = _inputAndOutput.afterTokenTransferDecode();

        theGauge.afterTokenTransfer(
            input.sender,
            input.senderBalance,
            input.recipient,
            input.recipientBalance,
            input.totalSupply
        );
    }

    function hookReceiverConfig(address _silo)
        external
        view
        virtual
        override(PartialLiquidation, IHookReceiver)
        returns (uint24 hooksBefore, uint24 hooksAfter)
    {
        return _hookReceiverConfig(_silo);
    }

    /// @notice Get the token type for the share token
    /// @param _silo Silo address for which tokens was deployed
    /// @param _shareToken Share token address
    /// @dev Revert if wrong silo
    /// @dev Revert if the share token is not one of the collateral, protected or debt tokens
    function _getTokenType(address _silo, address _shareToken) internal view virtual returns (uint256) {
        address collateralShareToken = siloConfig.getCollateralShareTokenStorage(_silo);

        if (_shareToken == collateralShareToken) return Hook.COLLATERAL_TOKEN;

        (
            address protectedShareToken,
            ,
            address debtShareToken
        ) = siloConfig.getShareTokens(_silo);

        if (_shareToken == protectedShareToken) return Hook.PROTECTED_TOKEN;
        if (_shareToken == debtShareToken) return Hook.DEBT_TOKEN;

        revert InvalidShareToken();
    }
}
