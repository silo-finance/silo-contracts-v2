// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Initializable} from "openzeppelin5/proxy/utils/Initializable.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";

import {GaugeHookReceiver} from "silo-core/contracts/utils/hook-receivers/gauge/GaugeHookReceiver.sol";
import {PartialLiquidation} from "silo-core/contracts/utils/hook-receivers/liquidation/PartialLiquidation.sol";
import {SiloHookReceiver} from "./_common/SiloHookReceiver.sol";

contract SiloHookV1 is GaugeHookReceiver, PartialLiquidation, SiloHookReceiver, Initializable {
    ISiloConfig public siloConfig;

    constructor() GaugeHookReceiver() {
        _disableInitializers();
    }

    /// @inheritdoc IHookReceiver
    function initialize(ISiloConfig _config, bytes calldata _data)
        public
        virtual
        initializer
    {
        require(address(_config) != address(0), EmptySiloConfig());
        require(address(siloConfig) == address(0), AlreadyConfigured());

        siloConfig = _config;

        GaugeHookReceiver._initialize(_data);

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
        override(GaugeHookReceiver, IHookReceiver)
    {
        GaugeHookReceiver.afterAction(_silo, _action, _inputAndOutput);

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
        override(GaugeHookReceiver, SiloHookReceiver)
    {
        SiloHookReceiver._setHookConfig(_silo, _hooksBefore, _hooksAfter);
    }

    /// @inheritdoc SiloHookReceiver
    function _getHooksAfter(address _silo)
        internal
        view
        override(GaugeHookReceiver, SiloHookReceiver)
        returns (uint256 hooksAfter)
    {
        hooksAfter = SiloHookReceiver._getHooksAfter(_silo);
    }

    function _siloConfig() internal override(PartialLiquidation, GaugeHookReceiver) view returns (ISiloConfig) {
        return siloConfig;
    }
}
