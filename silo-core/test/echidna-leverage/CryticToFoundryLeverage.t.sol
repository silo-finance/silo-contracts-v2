// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import "forge-std/console.sol";

import {Actor} from "silo-core/test/invariants/utils/Actor.sol";

// Contracts
import {LeverageTester} from "./LeverageTester.t.sol";
import {SetupLeverage} from "./SetupLeverage.t.sol";
import {InvariantsLeverage} from "./InvariantsLeverage.t.sol";
import {LeverageHandler} from "./handlers/user/LeverageHandler.t.sol";

/*
 * Test suite that converts from  "fuzz tests" to foundry "unit tests"
 * The objective is to go from random values to hardcoded values that can be analyzed more easily
 */
contract CryticToFoundryLeverage is InvariantsLeverage, SetupLeverage {
    uint256 constant DEFAULT_TIMESTAMP = 337812;

    CryticToFoundryLeverage LeverageTester = this;

    //    modifier setup(uint256 _i) override {
    //        targetActor = actorAddresses[_i % actorAddresses.length];
    //        actor = Actor(payable(targetActor));
    //
    //        assertTrue(targetActor != address(0), "setupActor fail: targetActor zero");
    //        assertTrue(address(actor) != address(0), "setupActor fail: actor zero");
    //
    //        require(targetActor != address(0), "setupActor fail: targetActor zero");
    //        require(address(actor) != address(0), "setupActor fail: actor zero");
    //
    //        _;
    //
    //        actor = Actor(payable(address(0)));
    //        targetActor = address(0);
    //    }

    function setUp() public {
        // Deploy protocol contracts
        _setUp();

        // Deploy actors
        _setUpActors();

        // Initialize handler contracts
        _setUpHandlers();

        /// @dev fixes the actor to the first user
        actor = actors[USER1];

        vm.warp(DEFAULT_TIMESTAMP);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                 FAILING INVARIANTS REPLAY                                 //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                              FAILING POSTCONDITIONS REPLAY                                //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /*
    FOUNDRY_PROFILE=echidna_leverage forge test -vv --ffi --mt test_replay_leverage
    */
    function test_replay_leverage() public {
        LeverageTester.deposit(3108972722022, 0, 1, 1);
        LeverageTester.openLeveragePosition(100000000000000001, 23, LeverageHandler.RandomGenerator2(25, 0, 10));
    }
}
