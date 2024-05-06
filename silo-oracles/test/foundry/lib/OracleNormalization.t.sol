// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";
import {OracleNormalization} from "../../../contracts/lib/OracleNormalization.sol";

/*
    FOUNDRY_PROFILE=oracles forge test -vv --match-contract OracleNormalizationTest
*/
contract OracleNormalizationTest is Test {
    /*
        FOUNDRY_PROFILE=oracles forge test -vvv --mt test_OracleNormalization_normalizationNumbers
    */
    function test_OracleNormalization_normalizationNumbers_18to18() public {
        vm.mockCall(address(1), abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(18));
        vm.mockCall(address(2), abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(18));
        uint256 priceDecimals = 8;
        (uint256 divider, uint256 multiplier) = OracleNormalization.normalizationNumbers(IERC20Metadata(address(1)), IERC20Metadata(address(2)), priceDecimals, 0);

        assertEq(divider, 10 ** (18 + 8 - 18));
        assertEq(multiplier, 0);
    }

    function test_OracleNormalization_normalizationNumbers_18to6() public {
        vm.mockCall(address(1), abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(18));
        vm.mockCall(address(2), abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(6));
        uint256 priceDecimals = 8;
        (uint256 divider, uint256 multiplier) = OracleNormalization.normalizationNumbers(IERC20Metadata(address(1)), IERC20Metadata(address(2)), priceDecimals, 0);

        assertEq(divider, 10 ** (18 + 8 - 6));
        assertEq(multiplier, 0);

        priceDecimals = 18;
        (divider, multiplier) = OracleNormalization.normalizationNumbers(IERC20Metadata(address(1)), IERC20Metadata(address(2)), priceDecimals, 0);

        assertEq(divider, 10 ** (18 + 18 - 6));
        assertEq(multiplier, 0);
    }

    function test_OracleNormalization_normalizationNumbers_6to18() public {
        vm.mockCall(address(1), abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(6));
        vm.mockCall(address(2), abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(18));
        uint256 priceDecimals = 8;

        (uint256 divider, uint256 multiplier) = OracleNormalization.normalizationNumbers(IERC20Metadata(address(1)), IERC20Metadata(address(2)), priceDecimals, 0);

        assertEq(divider, 0);
        assertEq(multiplier, 10 ** (18 - (8 + 6)));
    }

    /*
        FOUNDRY_PROFILE=oracles forge test -vvv --mt test_OracleNormalization_normalizePrice
    */
    function test_OracleNormalization_normalizePriceUsd() public {
        uint128 assetPrice = 5e7; // this is $0.5 in USD, 8 decimals
        uint256 priceDecimals = 8;

        uint256 expectedPriceInUsd = 1e6;

        vm.mockCall(address(1), abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(18));
        vm.mockCall(address(2), abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(6));
        (uint256 divider, uint256 multiplier) = OracleNormalization.normalizationNumbers(IERC20Metadata(address(1)), IERC20Metadata(address(2)), priceDecimals, 0);

        assertEq(OracleNormalization.normalizePrice(2e18, assetPrice, divider, multiplier), expectedPriceInUsd, "expecting 6 decimals quote");
    }

    /*
        FOUNDRY_PROFILE=oracles forge test -vv --mt test_OracleNormalization_normalizePriceEth
    */
    function test_OracleNormalization_normalizePriceEth() public {
        uint128 assetPrice = 5e5; // this is asset price $0.5 in USD, 6 decimals
        uint256 priceDecimals = 6;
        uint256 baseDecimals = 18;
        uint256 baseAmount = 2 * 1800 * 10 ** baseDecimals; // base amount

        uint256 quoteDecimals = 10; // ETH decimals, because ETH is quote

        uint128 ethPriceInUsd = 1800e8; // this is ETH/USD, 8 decimals
        uint256 ethPriceDecimals = 8;

        uint256 expectedPriceInEth = 1 * 10 ** quoteDecimals;

        vm.mockCall(address(1), abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(baseDecimals));
        vm.mockCall(address(2), abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(quoteDecimals));

        (uint256 divider, uint256 multiplier) = OracleNormalization.normalizationNumbers(
            IERC20Metadata(address(1)), IERC20Metadata(address(2)), priceDecimals, ethPriceDecimals
        );

        emit log_named_uint("divider", divider);
        emit log_named_uint("multiplier", multiplier);
        assertEq(multiplier, 0, "multiplier");

        emit log_named_decimal_uint("asset value in USD", baseAmount * assetPrice / divider, quoteDecimals);

        uint256 calculatedPriceInEth = baseAmount * assetPrice / divider / ethPriceInUsd;
        emit log_named_decimal_uint("asset value in ETH", calculatedPriceInEth, quoteDecimals);
        assertEq(calculatedPriceInEth, expectedPriceInEth, "calculatedPriceInEth == expectedPriceInEth");

        uint256 normalizedPrice = OracleNormalization.normalizePrices(
            baseAmount, assetPrice, ethPriceInUsd, divider, multiplier
        );

        assertEq(normalizedPrice, calculatedPriceInEth, "invalid normalizedPrice");
    }

    function test_OracleNormalization_normalizePriceEth_withMultiplier() public {
        uint128 assetPrice = 5e5; // this is asset price $0.5 in USD, 6 decimals
        uint256 priceDecimals = 6;
        uint256 baseDecimals = 18;
        uint256 baseAmount = 2 * 1800 * 10 ** baseDecimals; // base amount

        uint256 quoteDecimals = 18; // ETH decimals, because ETH is quote

        uint128 ethPriceInUsd = 1800e8; // this is ETH/USD, 8 decimals
        uint256 ethPriceDecimals = 8;

        uint256 expectedPriceInEth = 1 * 10 ** quoteDecimals;

        vm.mockCall(address(1), abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(baseDecimals));
        vm.mockCall(address(2), abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(quoteDecimals));

        (uint256 divider, uint256 multiplier) = OracleNormalization.normalizationNumbers(
            IERC20Metadata(address(1)), IERC20Metadata(address(2)), priceDecimals, ethPriceDecimals
        );

        emit log_named_uint("divider", divider);
        emit log_named_uint("multiplier", multiplier);
        assertEq(divider, 0, "divider");

        emit log_named_decimal_uint("asset value in USD", baseAmount * assetPrice * multiplier, quoteDecimals);

        uint256 calculatedPriceInEth = baseAmount * assetPrice * multiplier / ethPriceInUsd;
        emit log_named_decimal_uint("asset value in ETH", calculatedPriceInEth, quoteDecimals);
        assertEq(calculatedPriceInEth, expectedPriceInEth, "calculatedPriceInEth == expectedPriceInEth");

        uint256 normalizedPrice = OracleNormalization.normalizePrices(
            baseAmount, assetPrice, ethPriceInUsd, divider, multiplier
        );

        assertEq(normalizedPrice, calculatedPriceInEth, "invalid normalizedPrice");
    }

    function test_OracleNormalization_normalizePriceEth_SPELL() public {
        uint128 assetPrice = 40375; // SPELL price in USD, 8 decimals
        uint256 priceDecimals = 8;
        uint256 baseDecimals = 18;
        uint256 baseAmount = 1 * 10 ** baseDecimals; // base amount

        uint256 quoteDecimals = 18; // ETH decimals, because ETH is quote

        uint128 ethPriceInUsd = 1716_00000000; // this is ETH/USD, 8 decimals

        uint256 ethPriceDecimals = 8;

        uint256 expectedPriceInEth = 235285547785; // 0.000000235285547786

        vm.mockCall(address(1), abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(baseDecimals));
        vm.mockCall(address(2), abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(quoteDecimals));

        (uint256 divider, uint256 multiplier) = OracleNormalization.normalizationNumbers(
            IERC20Metadata(address(1)), IERC20Metadata(address(2)), priceDecimals, ethPriceDecimals
        );

        emit log_named_uint("divider", divider);
        emit log_named_uint("multiplier", multiplier);

        emit log_named_decimal_uint("SPELL value in USD", baseAmount * assetPrice / divider, quoteDecimals);

        uint256 calculatedPriceInEth = baseAmount * assetPrice / divider / ethPriceInUsd;
        emit log_named_decimal_uint("SPELL value in ETH", calculatedPriceInEth, quoteDecimals);
        assertEq(calculatedPriceInEth, expectedPriceInEth);

        uint256 normalizedPrice = OracleNormalization.normalizePrices(
            baseAmount, assetPrice, ethPriceInUsd, divider, multiplier
        );

        assertEq(normalizedPrice, calculatedPriceInEth);
    }
}
