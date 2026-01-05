// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import {Actor} from "silo-core/test/invariants/utils/Actor.sol";

// Contracts
import {SetupHookV3} from "./SetupHookV3.t.sol";
import {InvariantsDefaulting} from "../siloHookV2/InvariantsDefaulting.t.sol";

// solhint-disable function-max-lines, func-name-mixedcase

/*
 * Test suite that converts from  "fuzz tests" to foundry "unit tests"
 * The objective is to go from random values to hardcoded values that can be analyzed more easily
 */
contract CryticToFoundryHookV3 is InvariantsDefaulting, SetupHookV3 {
    uint256 public constant DEFAULT_TIMESTAMP = 337812;

    CryticToFoundryHookV3 public DefaultingTester = this;

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
    FOUNDRY_PROFILE=echidna_hookV3 forge test -vv --ffi --mt test_EchidnaDefaulting_empty
    */
    function test_EchidnaDefaulting_empty() public {
        // DefaultingTester.deposit(1, 0, 0, 0);
        // DefaultingTester.openDefaultingPosition(4506857007, 0, RandomGenerator(1, 0, 0));
    }
}
