// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Initializable} from "openzeppelin5/proxy/utils/Initializable.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";

import {GaugeHookReceiverCopy} from "silo-core/contracts/utils/hook-receivers/gauge/GaugeHookReceiverCopy.sol";
import {PartialLiquidationCopy} from "silo-core/contracts/utils/hook-receivers/liquidation/PartialLiquidationCopy.sol";
import {SiloHookReceiver} from "./_common/SiloHookReceiver.sol";

contract SiloHookV1 is GaugeHookReceiverCopy, PartialLiquidationCopy, SiloHookReceiver, Initializable {
    ISiloConfig public siloConfig;

    constructor() GaugeHookReceiverCopy() {
        _disableInitializers();
    }

    /// @inheritdoc IHookReceiver
    function initialize(ISiloConfig _siloConfig, bytes calldata _data)
        public
        virtual
        initializer
    {
        require(address(_siloConfig) != address(0), EmptySiloConfig());
        require(address(siloConfig) == address(0), AlreadyConfigured());

        siloConfig = _siloConfig;

        GaugeHookReceiverCopy._initialize(_data);

        // do your initialization here
    }

    /// @inheritdoc IHookReceiver
    function beforeAction(address, uint256, bytes calldata)
        public
        virtual
    {
        // Do not expect any actions.
        revert RequestNotSupported();

        // implement your logic here if needed and remove the revert
    }

    /// @inheritdoc IHookReceiver
    function afterAction(address _silo, uint256 _action, bytes calldata _inputAndOutput)
        public
        virtual
        override(GaugeHookReceiverCopy, IHookReceiver)
    {
        GaugeHookReceiverCopy.afterAction(_silo, _action, _inputAndOutput);

        // implement your logic here if needed
    }

    /// @inheritdoc IHookReceiver
    function hookReceiverConfig(address _silo)
        external
        view
        virtual
        returns (uint24 hooksBefore, uint24 hooksAfter)
    {
        (hooksBefore, hooksAfter) = _hookReceiverConfig(_silo);
    }

    /// @inheritdoc SiloHookReceiver
    function _setHookConfig(address _silo, uint256 _hooksBefore, uint256 _hooksAfter)
        internal
        override(GaugeHookReceiverCopy, SiloHookReceiver)
    {
        SiloHookReceiver._setHookConfig(_silo, _hooksBefore, _hooksAfter);
    }

    /// @inheritdoc SiloHookReceiver
    function _getHooksAfter(address _silo)
        internal
        view
        override(GaugeHookReceiverCopy, SiloHookReceiver)
        returns (uint256 hooksAfter)
    {
        hooksAfter = SiloHookReceiver._getHooksAfter(_silo);
    }

    function _siloConfig() internal override(PartialLiquidationCopy, GaugeHookReceiverCopy) view returns (ISiloConfig) {
        return siloConfig;
    }
}
