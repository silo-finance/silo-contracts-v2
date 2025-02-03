// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Hook Contracts
import {DefaultBeforeAfterHooks} from "./DefaultBeforeAfterHooks.t.sol";

/// @title HookAggregator
/// @notice Helper contract to aggregate all before / after hook contracts, inherited on each handler
abstract contract HookAggregator is DefaultBeforeAfterHooks {
    /// @notice Modular hook selector, per module
    function _before() internal {
        for (uint256 i; i < silos.length; i++) {
            _defaultHooksBefore(silos[i]);
        }
    }

    /// @notice Modular hook selector, per module
    function _after() internal {
        for (uint256 i; i < silos.length; i++) {
            _defaultHooksAfter(silos[i]);

            // Postconditions
            _checkPostConditions(silos[i]);
        }
    }

    /// @notice Postconditions for the handlers
    function _checkPostConditions(address silo) internal {
        // BASE
        assert_BASE_GPOST_A(silo);
        assert_BASE_GPOST_BC(silo);
        assert_BASE_GPOST_D(silo);

        // BORROWING
        assert_BORROWING_GPOST_C(silo);
    }
}
