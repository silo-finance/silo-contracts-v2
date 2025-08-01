// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {DynamicKinkModelHandlers} from "silo-core/test/echidna-dkink-irm/DynamicKinkModelHandlers.t.sol";
import {Invariants} from "silo-core/test/echidna-dkink-irm/invariants/Invariants.t.sol";
import {IDynamicKinkModel} from "silo-core/contracts/interfaces/IDynamicKinkModel.sol";
import {IInterestRateModel} from "silo-core/contracts/interfaces/IInterestRateModel.sol";
import {DynamicKinkModelFactory} from "silo-core/contracts/interestRateModel/kink/DynamicKinkModelFactory.sol";

/*
 * Test suite that converts from "fuzz tests" to foundry "unit tests"
 * The objective is to go from random values to hardcoded values that can be analyzed more easily
 */
contract CryticToFoundry is DynamicKinkModelHandlers, Invariants, Test {
    CryticToFoundry Tester = this;
    uint256 constant DEFAULT_TIMESTAMP = 337812;

    function setUp() public {
        _deployDynamicKinkModel();
        _deploySiloMock();

        vm.warp(DEFAULT_TIMESTAMP);
    }

    /*
    Template for creating test cases from echidna output:
    
    FOUNDRY_PROFILE=echidna_dkink forge test -vv --ffi --mt test_example_template
    */
    function test_example_template() public {
        // Example: Deploy IRM with specific config
        IDynamicKinkModel.Config memory config = IDynamicKinkModel.Config({
            ulow: 0.8e18,
            u1: 0.85e18,
            u2: 0.9e18,
            ucrit: 0.95e18,
            rmin: 0.01e18,
            kmin: 0.05e18,
            kmax: 1e18,
            alpha: 0.01e18,
            cminus: 0.01e18,
            cplus: 0.02e18,
            c1: 0.85e18,
            c2: 0.9e18,
            dmax: 0.1e18
        });
    }

    // FOUNDRY_PROFILE=echidna_dkink forge test -vv --ffi --mt test_example_template_2
    function test_example_template_2() public {
        getCompoundInterestRateAndUpdate(2055374211089311770138864210343622575677199015095370699716,18915270423501506686847387894589987664420778678667846414467);
        
        IDynamicKinkModel.Config memory config = IDynamicKinkModel.Config({
            ulow: 0,
            u1: 0,
            u2: 0,
            ucrit: 0,
            rmin: 0,
            kmin: 0,
            kmax: 0,
            alpha: 0,
            cminus: 0,
            cplus: 0,
            c1: 0,
            c2: 0,
            dmax: 0
        });
        
        updateSetup(config, 0);

        assertTrue(echidna_test_utilization_initialized(), "Utilization not initialized");
    }
}
