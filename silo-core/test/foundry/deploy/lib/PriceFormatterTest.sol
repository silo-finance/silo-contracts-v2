// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Test} from "forge-std/Test.sol";
import {PriceFormatter} from "silo-core/deploy/lib/PriceFormatter.sol";

/*
FOUNDRY_PROFILE=core_test forge test -vv --ffi --mc PriceFormatterTest
*/
contract PriceFormatterTest is Test {

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_PriceFormatter_digits
    */
    function test_PriceFormatter_digits() public pure {
        assertEq(PriceFormatter.digits(0), "", "digits(0)");
        assertEq(PriceFormatter.digits(1), "", "digits(1)");
        assertEq(PriceFormatter.digits(123), "", "digits(123)");
        assertEq(PriceFormatter.digits(1e18), " [19 digits]", "digits(1e18)");
        assertEq(PriceFormatter.digits(1e6), " [7 digits]", "digits(1e6)");
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_PriceFormatter_formatNumberInE
    */
    function test_PriceFormatter_formatNumberInE() public pure {
        assertEq(PriceFormatter.formatNumberInE(0), "0", "formatNumberInE(0)");
        assertEq(PriceFormatter.formatNumberInE(1), "1", "formatNumberInE(1)");
        assertEq(PriceFormatter.formatNumberInE(123456), "123456 [6 digits]", "formatNumberInE(123456)");
        assertEq(PriceFormatter.formatNumberInE(12345678), "12345678 [8 digits]", "formatNumberInE(12345678)");
        assertEq(PriceFormatter.formatNumberInE(12340000), "1234e4 [8 digits]", "formatNumberInE(12340000)");
        assertEq(PriceFormatter.formatNumberInE(1.2e18), "12e17 [19 digits]", "formatNumberInE(1.2e18)");
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_PriceFormatter_format18
    */
    function test_PriceFormatter_format18() public pure {
        assertEq(PriceFormatter.formatPriceInE18(0), "0", "formatPriceInE18(0)");
        assertEq(PriceFormatter.formatPriceInE18(1), "1", "formatPriceInE18(1)");
        assertEq(PriceFormatter.formatPriceInE18(123256), "123256 [6 digits]", "formatPriceInE18(123256)");
        assertEq(PriceFormatter.formatPriceInE18(0.123e18), "0.123e18", "formatPriceInE18(0.123e18)");
        assertEq(PriceFormatter.formatPriceInE18(1.2e18), "1.2e18", "formatPriceInE18(1.2e18)");

    }
}
