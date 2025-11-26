// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Contracts
import {HandlerAggregator} from "../HandlerAggregator.t.sol";


/// @title SiloMarketInvariants
/// @notice Implements Invariants for the protocol
/// @dev Inherits HandlerAggregator to check actions in assertion testing mode
abstract contract SiloMarketInvariants is HandlerAggregator {
    
}
