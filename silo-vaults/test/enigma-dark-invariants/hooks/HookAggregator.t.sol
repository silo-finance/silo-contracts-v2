// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC4626, IERC20} from "openzeppelin5/interfaces/IERC4626.sol";

// Hook Contracts
import {DefaultBeforeAfterHooks} from "./DefaultBeforeAfterHooks.t.sol";

/// @title HookAggregator
/// @notice Helper contract to aggregate all before / after hook contracts, inherited on each handler
abstract contract HookAggregator is DefaultBeforeAfterHooks {
    /// @notice Initializer for the hooks
    function _setUpHooks() internal {
        _setUpDefaultHooks();
    }

    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                         HOOKS                                             //
    /////////////////////////////////////////////////////////////////////////////////////////////*/

    /// @notice Modular hook selector, per module
    function _before() internal {
        _defaultHooksBefore();
    }

    /// @notice Modular hook selector, per module
    function _after() internal {
        _defaultHooksAfter();

        // POST-CONDITIONS
        _checkPostConditions();
    }

    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                   POSTCONDITION CHECKS                                    //
    /////////////////////////////////////////////////////////////////////////////////////////////*/

    /// @notice Postconditions for the handlers
    function _checkPostConditions() internal {
        // Check general postconditions
        _checkGeneralPostConditions();

        // Check user postconditions
        for (uint256 i; i < actorAddresses.length; i++) {
            _checkUserPostConditions(actorAddresses[i]);
        }

        // Check market postconditions
        for (uint256 i; i < markets.length; i++) {
            _checkMarketPostConditions(markets[i]);
        }
    }

    function _checkGeneralPostConditions() internal {
        // Base
        assert_GPOST_BASE_A();
        assert_GPOST_BASE_C();

        // Fees
        assert_GPOST_FEES_A();

        // Accounting
        assert_GPOST_ACCOUNTING_A();
        assert_GPOST_ACCOUNTING_B();
        assert_GPOST_ACCOUNTING_C();
        assert_GPOST_ACCOUNTING_D();
        assert_GPOST_ACCOUNTING_E();

        // Reentrancy
        assert_GPOST_REENTRANCY_A();
    }

    /// @notice Postconditions for each user
    function _checkUserPostConditions(address user) internal {
        // Check user postconditions
    }

    /// @notice Postconditions for each market
    function _checkMarketPostConditions(IERC4626 market) internal {
        assert_GPOST_BASE_B(market);
        assert_GPOST_BASE_D(market);
    }
}
