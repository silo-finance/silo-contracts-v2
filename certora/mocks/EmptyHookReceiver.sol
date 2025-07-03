// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";
import {BaseHookReceiver} from "silo-core/contracts/hooks/_common/BaseHookReceiver.sol";

/// @notice Silo share token hook receiver for the gauge.
/// It notifies the gauge (if configured) about any balance update in the Silo share token.
contract EmptyHookReceiver is BaseHookReceiver {
    using Hook for uint256;
    using Hook for bytes;

    uint24 internal constant HOOKS_BEFORE_NOT_CONFIGURED = 0;

    /// @inheritdoc IHookReceiver
    function initialize(ISiloConfig _siloConfig, bytes calldata _data) external {
        siloConfig = _siloConfig;
    }

    /// @inheritdoc IHookReceiver
    function beforeAction(address, uint256, bytes calldata) external pure {
        // Do not expect any actions.
    }

    /// @inheritdoc IHookReceiver
    function afterAction(address _silo, uint256 _action, bytes calldata _inputAndOutput) external {
        // Do not expect any actions.
    }
}
