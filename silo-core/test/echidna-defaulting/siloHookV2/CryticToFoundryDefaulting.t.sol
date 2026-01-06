// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import {Actor} from "silo-core/test/invariants/utils/Actor.sol";

// Contracts
import {SetupDefaulting} from "./SetupDefaulting.t.sol";
import {InvariantsDefaulting} from "./InvariantsDefaulting.t.sol";

// solhint-disable function-max-lines, func-name-mixedcase

/*
 * Test suite that converts from  "fuzz tests" to foundry "unit tests"
 * The objective is to go from random values to hardcoded values that can be analyzed more easily
 */
contract CryticToFoundryDefaulting is InvariantsDefaulting, SetupDefaulting {
    uint256 public constant DEFAULT_TIMESTAMP = 337812;

    CryticToFoundryDefaulting public DefaultingTester = this;

    function setUp() public {
        // Deploy protocol contracts
        _setUp();

        // Deploy actors
        _setUpActors();

        // Initialize handler contracts
        _setUpHandlers();

        vm.warp(DEFAULT_TIMESTAMP);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                 FAILING INVARIANTS REPLAY                                 //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                              FAILING POSTCONDITIONS REPLAY                                //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /*
    FOUNDRY_PROFILE=echidna_defaulting forge test -vv --ffi --mt test_EchidnaDefaulting_empty
    */
    function test_EchidnaDefaulting_empty() public {}

    /*
    FOUNDRY_PROFILE=echidna_defaulting forge test -vv --ffi --mt test_EchidnaDefaulting_test1
    */
    function test_EchidnaDefaulting_test1() public {
        DefaultingTester.deposit(26, 1, 1, 0);
        DefaultingTester.liquidationCallByDefaulting(0, RandomGenerator(0, 0, 0));
    }
}
