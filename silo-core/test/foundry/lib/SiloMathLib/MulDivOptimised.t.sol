// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {StringsUpgradeable as Strings} from "openzeppelin-contracts-upgradeable/utils/StringsUpgradeable.sol";
import {MathUpgradeable} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";

import {SiloMathLib} from "silo-core/contracts/lib/SiloMathLib.sol";

// forge test -vv --mc ConvertToAssetsTest
contract MulDivOptimisedTest is Test {
    struct TestCase {
        uint256 x;
        uint256 y;
        uint256 d;
        SiloMathLib.Rounding rounding;
    }

    TestCase[] testCases;

    function setUp() public {
        testCases.push(TestCase({x: 0, y: 0, d: 1, rounding: SiloMathLib.Rounding.Down}));
        testCases.push(TestCase({x: 0, y: 0, d: 1, rounding: SiloMathLib.Rounding.Up}));
        testCases.push(TestCase({x: 123, y: 1, d: 3, rounding: SiloMathLib.Rounding.Up}));
        testCases.push(TestCase({x: 123, y: 1, d: 3, rounding: SiloMathLib.Rounding.Down}));
        testCases.push(TestCase({x: type(uint128).max - 1, y: type(uint128).max, d: 1, rounding: SiloMathLib.Rounding.Down}));
        testCases.push(TestCase({x: type(uint128).max - 1, y: type(uint128).max, d: 1, rounding: SiloMathLib.Rounding.Up}));
        testCases.push(TestCase({x: type(uint128).max, y: type(uint128).max, d: 1, rounding: SiloMathLib.Rounding.Down}));
        testCases.push(TestCase({x: type(uint128).max, y: type(uint128).max, d: 1, rounding: SiloMathLib.Rounding.Up}));
        testCases.push(TestCase({x: type(uint128).max, y: type(uint128).max, d: 3, rounding: SiloMathLib.Rounding.Down}));
        testCases.push(TestCase({x: type(uint128).max, y: type(uint128).max, d: 3, rounding: SiloMathLib.Rounding.Up}));
    }

    /*
    forge test -vv --mt test_mulDivOptimised
    */
    function test_mulDivOptimised() public {
        uint256 numberOfTestCases = testCases.length;

        for (uint256 index = 0; index < numberOfTestCases; index++) {
            TestCase memory useCase = testCases[index];

            uint256 siloLib = SiloMathLib.mulDivOptimised(useCase.x, useCase.y, useCase.d, useCase.rounding);

            uint256 openLib = MathUpgradeable.mulDiv(
                useCase.x, useCase.y, useCase.d, MathUpgradeable.Rounding(uint8(useCase.rounding))
            );

            assertEq(siloLib, openLib, string.concat(Strings.toString(index), "expect the same results"));
        }
    }
}
