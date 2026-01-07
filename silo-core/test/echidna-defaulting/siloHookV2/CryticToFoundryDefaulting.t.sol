// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console2} from "forge-std/console2.sol";

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
        DefaultingTester.deposit(373802,37,7,1);
        DefaultingTester.deposit(224,14,14,2);
        DefaultingTester.assertBORROWING_HSPOST_F(26,99);
        DefaultingTester.assert_LENDING_INVARIANT_B(1,1);
        DefaultingTester.redeem(564111571638124458312908753592908497545482174852052485523908247209548,0,1,0);
        //  Time delay: 106979 seconds Block delay: 18
        // *wait* Time delay: 265077 seconds Block delay: 519
        vm.warp(block.timestamp + 265077 + 106979);
        DefaultingTester.accrueInterestForSilo(0);
        address borrower = _getRandomActor(80);
        (uint256 collateral, uint256 debt,) = liquidationModule.maxLiquidation(borrower);
        console2.log("collateral", collateral);
        console2.log("debt", debt);
        console2.log("maxRepay", vault1.maxRepay(borrower));
        DefaultingTester.liquidationCallByDefaulting(11341165459103450728475532188145079651503353303312141862775511628633163519, RandomGenerator(0, 80, 1));

    }
}
