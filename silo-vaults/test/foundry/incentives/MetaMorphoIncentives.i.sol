// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {UtilsLib} from "morpho-blue/libraries/UtilsLib.sol";

import {ErrorsLib} from "../../../contracts/libraries/ErrorsLib.sol";
import {IntegrationTest} from "../helpers/IntegrationTest.sol";
import {NB_MARKETS, CAP, MIN_TEST_ASSETS, MAX_TEST_ASSETS} from "../helpers/BaseTest.sol";

/*
 FOUNDRY_PROFILE=vaults-tests forge test --ffi --mc MetaMorphoInternalTest -vvv
*/
contract MetaMorphoIncentivesTest is IntegrationTest {
    function setUp() public override {
        super.setUp();

        _setCap(allMarkets[0], CAP);
        _setCap(allMarkets[1], CAP);
        _setCap(allMarkets[2], CAP);
    }

    /*
     FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt test_vaults_incentives_dummy -vv
     boilerplate for integration tests
    */
    function test_vaults_incentives_dummy() public {
        assertTrue(address(vault.INCENTIVES_MODULE()) != address(0), "INCENTIVES_MODULE");

        vault.deposit(1, address(this));
    }
}
