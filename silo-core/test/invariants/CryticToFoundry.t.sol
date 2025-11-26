// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Contracts
import {Setup} from "./Setup.t.sol";

/*
 * Test suite that converts from  "fuzz tests" to foundry "unit tests"
 * The objective is to go from random values to hardcoded values that can be analyzed more easily
 */
contract CryticToFoundry is Setup {
    function setUp() public {
        // Deploy protocol contracts
        _setUp();

        // Deploy actors
        _setUpActors();
    }
}
