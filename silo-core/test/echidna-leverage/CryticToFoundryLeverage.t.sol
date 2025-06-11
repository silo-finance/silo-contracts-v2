// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import "forge-std/console.sol";

// Contracts
import {CryticToFoundry} from "silo-core/test/invariants/CryticToFoundry.t.sol";

/*
 * Test suite that converts from  "fuzz tests" to foundry "unit tests"
 * The objective is to go from random values to hardcoded values that can be analyzed more easily
 */
contract CryticToFoundryLeverage is CryticToFoundry {
    CryticToFoundryLeverage Tester = this;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                 FAILING INVARIANTS REPLAY                                 //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                              FAILING POSTCONDITIONS REPLAY                                //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /*
    FOUNDRY_PROFILE=core-with-invariants forge test -vv --ffi --mt test_replay_leverage
    */
    function test_replay_leverage() public {
        Tester.deposit(2,0,0,1);
    }
}
