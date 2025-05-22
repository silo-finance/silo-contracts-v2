// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";

import {IncentiveHook} from "silo-core/contracts/hooks/incentive/IncentiveHook.sol";
import {PartialLiquidation} from "silo-core/contracts/hooks/liquidation/PartialLiquidation.sol";
import {BaseHookReceiver} from "silo-core/contracts/hooks/_common/BaseHookReceiver.sol";

import {console2} from "forge-std/console2.sol";

contract SiloHookV1 is IncentiveHook, PartialLiquidation {
    /// @inheritdoc IHookReceiver
    function initialize(ISiloConfig _config, bytes calldata _data)
        public
        initializer
        virtual
    {
        (address owner) = abi.decode(_data, (address));

        BaseHookReceiver.__BaseHookReceiver_init(_config);
        IncentiveHook.__IncentiveHook_init(owner);
    }

    /// @inheritdoc IHookReceiver
    function beforeAction(address _silo, uint256 _action, bytes calldata _inputAndOutput)
        public
        virtual
        onlySilo()
        override(IncentiveHook, IHookReceiver)
    {
        IncentiveHook.beforeAction(_silo, _action, _inputAndOutput);
    }

    /// @inheritdoc IHookReceiver
    function afterAction(address _silo, uint256 _action, bytes calldata _inputAndOutput)
        public
        virtual
        onlySiloOrShareToken()
        override(IncentiveHook, IHookReceiver)
    {
        console2.log("[afterAction] SiloHookV1");
        IncentiveHook.afterAction(_silo, _action, _inputAndOutput);
    }
}
