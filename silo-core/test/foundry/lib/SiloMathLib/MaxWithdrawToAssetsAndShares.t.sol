// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {SiloMathLib} from "silo-core/contracts/lib/SiloMathLib.sol";
import {MaxWithdrawToAssetsAndSharesTestData} from "../../data-readers/MaxWithdrawToAssetsAndSharesTestData.sol";

// forge test -vv --mc MaxWithdrawToAssetsAndSharesTest
contract MaxWithdrawToAssetsAndSharesTest is Test {
    /*
    forge test -vv --mt test_maxWithdrawToAssetsAndShares_loop
    */
    function test_maxWithdrawToAssetsAndShares_loop() public {
        MaxWithdrawToAssetsAndSharesTestData tests = new MaxWithdrawToAssetsAndSharesTestData();
        MaxWithdrawToAssetsAndSharesTestData.MWTASData[] memory testDatas = tests.getData();

        for (uint256 i; i < testDatas.length; i++) {
            // emit log_string(testDatas[i].name);
            // emit log_named_uint("testDatas[i].output.assets", testDatas[i].output.assets);

            (uint256 assets, uint256 shares) = SiloMathLib.maxWithdrawToAssetsAndShares(
                testDatas[i].input.maxAssets,
                testDatas[i].input.borrowerCollateralAssets,
                testDatas[i].input.borrowerProtectedAssets,
                testDatas[i].input.assetType,
                testDatas[i].input.totalAssets,
                testDatas[i].input.assetTypeShareTokenTotalSupply,
                testDatas[i].input.liquidity
            );

            assertEq(assets, testDatas[i].output.assets, string.concat(testDatas[i].name, " => assets"));
            assertEq(shares, testDatas[i].output.shares, string.concat(testDatas[i].name, " => shares"));
        }
    }
}
