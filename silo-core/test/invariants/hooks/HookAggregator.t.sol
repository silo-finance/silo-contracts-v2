// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Hook Contracts
import {DefaultBeforeAfterHooks} from "./DefaultBeforeAfterHooks.t.sol";

/// @title HookAggregator
/// @notice Helper contract to aggregate all before / after hook contracts, inherited on each handler
abstract contract HookAggregator is DefaultBeforeAfterHooks {
    /// @notice Modular hook selector, per module
    function _before() internal {
        _defaultHooksBefore();
    }

    /// @notice Modular hook selector, per module
    function _after() internal {
        _defaultHooksAfter();

        // Postconditions
        _checkPostConditions();
    }

    /// @notice Postconditions for the handlers
    function _checkPostConditions() internal {
        // Implement post conditions here
    }
}
