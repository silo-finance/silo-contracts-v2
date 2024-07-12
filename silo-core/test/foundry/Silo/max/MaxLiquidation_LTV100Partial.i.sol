// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {MaxLiquidationCommon} from "./MaxLiquidationCommon.sol";

/*
    forge test -vv --ffi --mc MaxLiquidationLTV100PartialTest

    cases where we go from solvent to 100% and we can do partial liquidation
*/
contract MaxLiquidationLTV100PartialTest is MaxLiquidationCommon {
    /*
    forge test -vv --ffi --mt test_maxLiquidation_LTV100_partial_1token_sTokens_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 100
    function test_maxLiquidation_LTV100_partial_1token_sTokens() public {
        // I did not found cases for this scenario
    }

    /*
    forge test -vv --ffi --mt test_maxLiquidation_LTV100_partial_1token_tokens_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 100
    function test_maxLiquidation_LTV100_partial_1token_tokens() public {
        // I did not found cases for this scenario
    }

    /*
    forge test -vv --ffi --mt test_maxLiquidation_LTV100_partial_2tokens_sToken_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 100
    function test_maxLiquidation_LTV100_partial_2tokens_sToken() public {
        // I did not found cases for this scenario
    }

    /*
    forge test -vv --ffi --mt test_maxLiquidation_LTV100_partial_2tokens_token_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 100
    function test_maxLiquidation_LTV100_partial_2tokens_token() public {
        // I did not found cases for this scenario
    }
}
