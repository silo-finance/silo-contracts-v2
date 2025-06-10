// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Invariants} from "./invariants/Invariants.t.sol";
import {Setup} from "./base/Setup.t.sol";

/// @title Tester
/// @dev make echidna-x-silo
/// tutorial https://secure-contracts.com/program-analysis/echidna/index.html
contract XSiloTester is Invariants, Setup {
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
