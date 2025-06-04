// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Contracts
import {XSilo} from "x-silo/contracts/XSilo.sol";
import {Stream} from "x-silo/contracts/modules/Stream.sol";

// Utils
import {Actor} from "../utils/Actor.sol";

/// @notice BaseStorage contract for all test contracts, works in tandem with BaseTest
abstract contract BaseStorage {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       CONSTANTS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    uint256 constant MAX_TOKEN_AMOUNT = 1e29;

    uint256 constant ONE_DAY = 1 days;
    uint256 constant ONE_MONTH = ONE_YEAR / 12;
    uint256 constant ONE_YEAR = 365 days;

    uint256 internal constant NUMBER_OF_ACTORS = 3;
    uint256 internal constant INITIAL_ETH_BALANCE = 1e26;

    address internal constant QUOTE_TOKEN_ADDRESS = address(0xdead);

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTORS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Stores the actor during a handler call
    Actor internal actor;

    /// @notice Mapping of fuzzer user addresses to actors
    mapping(address => Actor) internal actors;

    /// @notice Array of all actor addresses
    address[] internal actorAddresses;

    /// @notice The pool admin is set to this contract, the Tester contract
    address internal poolAdmin = address(this);

    /// @notice The actor to which hooks are applied to
    address internal targetActor;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                              SUITE STORAGE: PROTOCOL CONTRACTS                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    XSilo internal xSilo;
    Stream internal stream;

    address internal siloToken;
}
