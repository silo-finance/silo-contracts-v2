// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {InvariantsDefaulting} from "./InvariantsDefaulting.t.sol";
import {SetupDefaulting} from "./SetupDefaulting.t.sol";

/*
    make echidna-leverage-assert
    make echidna-leverage
*/
/// @title DefaultingTester
/// @notice Entry point for invariant testing, inherits all contracts, invariants & handler
/// @dev Mono contract that contains all the testing logic
contract DefaultingTester is InvariantsDefaulting, SetupDefaulting {
    constructor() payable {
        // Deploy protocol contracts and protocol actors
        setUp();
    }

    /// @dev Foundry compatibility faster setup debugging
    function setUp() internal {
        // Deploy protocol contracts and protocol actors
        _setUp();

        // Deploy actors
        _setUpActors();

        // Initialize handler contracts
        _setUpHandlers();
    }
}
