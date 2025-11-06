// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {GaugeHookReceiver} from "silo-core/contracts/hooks/gauge/GaugeHookReceiver.sol";
import {PartialLiquidationByDefaulting} from "silo-core/contracts/hooks/defaulting/PartialLiquidationByDefaulting.sol";
import {BaseHookReceiver} from "silo-core/contracts/hooks/_common/BaseHookReceiver.sol";

contract SiloHookV2 is GaugeHookReceiver, PartialLiquidationByDefaulting {
    /// @inheritdoc IHookReceiver
    function initialize(ISiloConfig _config, bytes calldata _data) public virtual initializer {
        (address owner, address defaultingCollateral) = abi.decode(_data, (address, address));

        BaseHookReceiver.__BaseHookReceiver_init(_config);
        GaugeHookReceiver.__GaugeHookReceiver_init(owner);
        PartialLiquidationByDefaulting.__PartialLiquidationByDefaulting_init(owner, defaultingCollateral);
    }

    /// @inheritdoc IHookReceiver
    function beforeAction(address, uint256, bytes calldata) public virtual override onlySilo {
        // Do not expect any actions.
        revert RequestNotSupported();
    }

    /// @inheritdoc IHookReceiver
    function afterAction(address _silo, uint256 _action, bytes calldata _inputAndOutput)
        public
        virtual
        override(GaugeHookReceiver, IHookReceiver)
        onlySiloOrShareToken
    {
        GaugeHookReceiver.afterAction(_silo, _action, _inputAndOutput);
    }
}
