// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Strings} from "openzeppelin5/utils/Strings.sol";

import {Test} from "forge-std/Test.sol";

import {SiloMathLib} from "silo-core/contracts/lib/SiloMathLib.sol";
import {CalculateMaxAssetsToWithdrawTestData} from "../../data-readers/CalculateMaxAssetsToWithdrawTestData.sol";

// forge test -vv --mc CalculateMaxAssetsToWithdrawTest
contract CalculateMaxAssetsToWithdrawTest is Test {
    uint256 internal constant _PRECISION_DECIMALS = 1e18;

    /*
    forge test -vv --mt test_calculateMaxAssetsToWithdraw
    */
    function test_calculateMaxAssetsToWithdraw() public {
        CalculateMaxAssetsToWithdrawTestData tests = new CalculateMaxAssetsToWithdrawTestData();
        CalculateMaxAssetsToWithdrawTestData.CMATWData[] memory testDatas = tests.getData();

        for (uint256 i; i < testDatas.length; i++) {
            CalculateMaxAssetsToWithdrawTestData.CMATWData memory testData = testDatas[i];

            uint256 maxAssets = SiloMathLib.calculateMaxAssetsToWithdraw(
                testData.input.sumOfCollateralsValue,
                testData.input.debtValue,
                testData.input.lt,
                testData.input.borrowerCollateralAssets,
                testData.input.borrowerProtectedAssets
            );

            uint256 collateralSum = testData.input.borrowerCollateralAssets + testData.input.borrowerProtectedAssets;
            assertLe(maxAssets, collateralSum, _concatMsg(i, string.concat(testData.name, " - max overflow")));

            assertEq(maxAssets, testData.maxAssets, _concatMsg(i, testData.name));

            uint256 ltvAfter = _ltv(testData);
            assertLe(ltvAfter, testData.input.lt, _concatMsg(i, string.concat(testData.name, " - LTV holds")));
        }
    }

    function _concatMsg(uint256 _i, string memory _msg) internal pure returns (string memory) {
        return string.concat("[", Strings.toString(_i), "] ", _msg);
    }

    function _ltv(CalculateMaxAssetsToWithdrawTestData.CMATWData memory testData) internal pure returns (uint256) {
        if (testData.input.debtValue == 0) return 0;

        uint256 collateralSum = testData.input.borrowerCollateralAssets + testData.input.borrowerProtectedAssets;
        uint256 collateralSumAfter = collateralSum - testData.maxAssets;

        if (collateralSum == 0) return 0;

        uint256 valueAfter = testData.input.sumOfCollateralsValue * collateralSumAfter / collateralSum;
        return testData.input.debtValue * 1e18 / valueAfter;
    }
}
