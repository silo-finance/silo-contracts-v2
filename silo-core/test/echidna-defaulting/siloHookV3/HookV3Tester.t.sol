// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {InvariantsDefaulting} from "../siloHookV2/InvariantsDefaulting.t.sol";
import {SetupHookV3} from "./SetupHookV3.t.sol";

/*
    make echidna-leverage-assert
    make echidna-leverage
*/
/// @title HookV3Tester
/// @notice Entry point for invariant testing, inherits all contracts, invariants & handler
/// @dev Mono contract that contains all the testing logic
contract HookV3Tester is InvariantsDefaulting, SetupHookV3 {
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
