// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Invariant Contracts
import {BaseInvariants} from "./invariants/BaseInvariants.t.sol";

/// @title Invariants
/// @notice Wrappers for the protocol invariants implemented in each invariants contract
/// @dev recognised by Echidna when property mode is activated
/// @dev Inherits BaseInvariants
abstract contract Invariants is BaseInvariants {
///////////////////////////////////////////////////////////////////////////////////////////////
//                                     BASE INVARIANTS                                       //
///////////////////////////////////////////////////////////////////////////////////////////////

/*  

    E.g. of an invariant wrapper recognized by Echidna and Medusa

    function echidna_BASE_INVARIANT() public returns (bool) {
        assert_BASE_INVARIANT_A();
        return true;
    } 
    */
}
