// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Pretty, Strings} from "../utils/Pretty.sol";

import {BaseHooks} from "../base/BaseHooks.t.sol";

/// @title Default Before After Hooks
/// @notice Helper contract for before and after hooks
/// @dev This contract is inherited by handlers
abstract contract DefaultBeforeAfterHooks is BaseHooks {
    using Strings for string;
    using Pretty for uint256;
    using Pretty for int256;
    using Pretty for bool;

    struct DefaultVars {
        uint256 balanceBefore;
        uint256 balanceAfter;
    }

    DefaultVars defaultVars;

    function _defaultHooksBefore() internal {}

    function _defaultHooksAfter() internal {}

    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                POST CONDITION INVARIANTS                                  //
    /////////////////////////////////////////////////////////////////////////////////////////////*/
}
