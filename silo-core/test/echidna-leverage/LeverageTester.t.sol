// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {InvariantsLeverage} from "./InvariantsLeverage.t.sol";
import {SetupLeverage} from "./SetupLeverage.t.sol";

/// @title LeverageTester
/// @notice Entry point for invariant testing, inherits all contracts, invariants & handler
/// @dev Mono contract that contains all the testing logic
contract LeverageTester is InvariantsLeverage, SetupLeverage {
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
