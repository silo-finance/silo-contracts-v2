// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "../../../contracts/lib/PairMath.sol";
import "../data-readers/PairMathTestData.sol";

/*
    FOUNDRY_PROFILE=amm-core forge test -vv --match-contract PairMathTest
*/
contract PairMathTest is Test {
    uint256 constant PRECISION = 1e18;
    uint256 constant FEE_PRECISION = 1e4;

    PairMathTestData pairMathTestData;

    constructor() {
        pairMathTestData = new PairMathTestData();
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_PairMath_getDebtIn
    */
    function test_PairMath_getDebtIn() public {
        unchecked {
            PairMathTestData.TestData[] memory testDatas = pairMathTestData.testData();

            uint256 gasSum;
            assertEq(testDatas.length, 3, "for proper gas check, update it when add more tests");

            for (uint i; i < testDatas.length; i++) {
                // emit log_named_uint("-------- i", i);
                PairMathTestData.TestData memory testData = testDatas[i];

                uint256 gasStart = gasleft();
                (uint256 exactIn, uint256 fee) = PairMath.getDebtIn(testData.debtQuote, testData.onSwapK, testData.fee);
                uint256 gasEnd = gasleft();
                gasSum += (gasStart - gasEnd);

                assertEq(exactIn, testData.debtAmountIn, "debtAmountIn");
                assertEq(fee, testData.debtAmountInFee, "debtAmountInFee");
            }

            assertEq(gasSum, 838, "make sure we gas efficient on price model actions");
        }
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_PairMath_getDebtInReverse
    */
    function test_PairMath_getDebtInReverse() public {
        unchecked {
            PairMathTestData.TestData[] memory testDatas = pairMathTestData.testData();

            uint256 gasSum;
            assertEq(testDatas.length, 3, "for proper gas check, update it when add more tests");

            for (uint i; i < testDatas.length; i++) {
                // emit log_named_uint("-------- i", i);
                PairMathTestData.TestData memory testData = testDatas[i];

                uint256 gasStart = gasleft();
                (uint256 result, uint256 fee) = PairMath.getDebtInReverse(testData.debtAmountIn, testData.onSwapK, testData.fee);
                uint256 gasEnd = gasleft();
                gasSum += (gasStart - gasEnd);

                assertEq(result, testData.debtQuote, "debtQuote");
                assertEq(fee, testData.debtAmountInFee, "debtAmountInFee");
            }

            assertEq(gasSum, 840, "make sure we gas efficient on price model actions");
        }
    }
}
