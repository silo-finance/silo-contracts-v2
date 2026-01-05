// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {ISilo} from "silo-core/contracts/Silo.sol";

// Invariant Contracts
import {Invariants} from "silo-core/test/invariants/Invariants.t.sol";
import {DefaultingHandler} from "./handlers/user/DefaultingHandler.t.sol";

/// @title Invariants
/// @notice Wrappers for the protocol invariants implemented in each invariants contract
/// @dev recognised by Echidna when property mode is activated
/// @dev Inherits BaseInvariants
abstract contract InvariantsDefaulting is Invariants, DefaultingHandler {
///////////////////////////////////////////////////////////////////////////////////////////////
//                                     BASE INVARIANTS                                       //
///////////////////////////////////////////////////////////////////////////////////////////////

//    function echidna_BORROWING_INVARIANT() public returns (bool) {

//    }
}
