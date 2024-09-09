// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Contracts
import {HandlerAggregator} from "../HandlerAggregator.t.sol";

/// @title BaseInvariants
/// @notice Implements Invariants for the protocol
/// @dev Inherits HandlerAggregator to check actions in assertion testing mode
abstract contract BaseInvariants is HandlerAggregator {
/*
    E.g. of an invariant  

    function assert_BASE_INVARIANT_A() internal {
        assertEq(eTST.getReentrancyLock(), false, BASE_INVARIANT_A);
    }
    */
}
