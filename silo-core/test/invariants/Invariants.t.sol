// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;


// Invariant Contracts
import {BaseInvariants} from "./invariants/BaseInvariants.t.sol";
import {SiloMarketInvariants} from "./invariants/SiloMarketInvariants.t.sol";
import {LendingBorrowingInvariants} from "./invariants/LendingBorrowingInvariants.t.sol";


/// @title Invariants
/// @notice Wrappers for the protocol invariants implemented in each invariants contract
/// @dev recognised by Echidna when property mode is activated
/// @dev Inherits BaseInvariants
abstract contract Invariants is BaseInvariants, SiloMarketInvariants, LendingBorrowingInvariants {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     BASE INVARIANTS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

}
