// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";
import "silo-core/contracts/lib/SiloMathLib.sol";

// forge test -vv --mc ConvertToSharesTest
contract ConvertToSharesTest is Test {
    struct TestCase {
        uint256 assets;
        uint256 totalAssets;
        uint256 totalShares;
        Math.Rounding rounding;
        ISilo.AssetType assetType;
        uint256 result;
    }

    uint256 public numberOfTestCases = 30;

    mapping(uint256 => TestCase) public cases;

    function setUp() public {
        cases[0] = TestCase({
            assets: 0,
            totalAssets: 0,
            totalShares: 0,
            rounding: Rounding.DOWN,
            assetType: ISilo.AssetType.Collateral,
            result: 0
        });

        cases[1] = TestCase({
            assets: 200000,
            totalAssets: 0,
            totalShares: 0,
            rounding: Rounding.DOWN,
            assetType: ISilo.AssetType.Collateral,
            result: 200000
        });

        cases[2] = TestCase({
            assets: 100,
            totalAssets: 5000,
            totalShares: 1000,
            rounding: Rounding.DOWN,
            assetType: ISilo.AssetType.Collateral,
            result: 20
        });

        cases[3] = TestCase({
            assets: 333,
            totalAssets: 999,
            totalShares: 999,
            rounding: Rounding.DOWN,
            assetType: ISilo.AssetType.Collateral,
            result: 333
        });

        cases[4] = TestCase({
            assets: 333,
            totalAssets: 1000,
            totalShares: 999,
            rounding: Rounding.DOWN,
            assetType: ISilo.AssetType.Collateral,
            result: 332
        });

        cases[5] = TestCase({
            assets: 333,
            totalAssets: 1000,
            totalShares: 999,
            rounding: Rounding.UP,
            assetType: ISilo.AssetType.Collateral,
            result: 333
        });

        cases[6] = TestCase({
            assets: 333,
            totalAssets: 999,
            totalShares: 1000,
            rounding: Rounding.DOWN,
            assetType: ISilo.AssetType.Collateral,
            result: 333
        });

        cases[7] = TestCase({
            assets: 333,
            totalAssets: 999,
            totalShares: 1000,
            rounding: Rounding.UP,
            assetType: ISilo.AssetType.Collateral,
            result: 334
        });

        cases[8] = TestCase({
            assets: 1,
            totalAssets: 1000,
            totalShares: 1,
            rounding: Rounding.DOWN,
            assetType: ISilo.AssetType.Collateral,
            result: 0
        });

        cases[9] = TestCase({
            assets: 1,
            totalAssets: 1,
            totalShares: 1000,
            rounding: Rounding.DOWN,
            assetType: ISilo.AssetType.Collateral,
            result: 500
        });

        cases[10] = TestCase({
            assets: 1,
            totalAssets: 1,
            totalShares: 1000,
            rounding: Rounding.UP,
            assetType: ISilo.AssetType.Collateral,
            result: 501
        });

        cases[11] = TestCase({
            assets: 0,
            totalAssets: 0,
            totalShares: 0,
            rounding: Rounding.DOWN,
            assetType: ISilo.AssetType.Debt,
            result: 0
        });

        cases[12] = TestCase({
            assets: 200000,
            totalAssets: 0,
            totalShares: 0,
            rounding: Rounding.DOWN,
            assetType: ISilo.AssetType.Debt,
            result: 200000
        });

        cases[13] = TestCase({
            assets: 100,
            totalAssets: 5000,
            totalShares: 1000,
            rounding: Rounding.DOWN,
            assetType: ISilo.AssetType.Debt,
            result: 20
        });

        cases[14] = TestCase({
            assets: 333,
            totalAssets: 999,
            totalShares: 999,
            rounding: Rounding.DOWN,
            assetType: ISilo.AssetType.Debt,
            result: 333
        });

        cases[15] = TestCase({
            assets: 333,
            totalAssets: 1000,
            totalShares: 999,
            rounding: Rounding.DOWN,
            assetType: ISilo.AssetType.Debt,
            result: 332
        });

        cases[16] = TestCase({
            assets: 333,
            totalAssets: 1000,
            totalShares: 999,
            rounding: Rounding.UP,
            assetType: ISilo.AssetType.Debt,
            result: 333
        });

        cases[17] = TestCase({
            assets: 333,
            totalAssets: 999,
            totalShares: 1000,
            rounding: Rounding.DOWN,
            assetType: ISilo.AssetType.Debt,
            result: 333
        });

        cases[18] = TestCase({
            assets: 333,
            totalAssets: 999,
            totalShares: 1000,
            rounding: Rounding.UP,
            assetType: ISilo.AssetType.Debt,
            result: 334
        });

        cases[19] = TestCase({
            assets: 1,
            totalAssets: 1000,
            totalShares: 1,
            rounding: Rounding.DOWN,
            assetType: ISilo.AssetType.Debt,
            result: 0
        });

        cases[20] = TestCase({
            assets: 1,
            totalAssets: 1,
            totalShares: 1000,
            rounding: Rounding.DOWN,
            assetType: ISilo.AssetType.Debt,
            result: 1000
        });

        cases[21] = TestCase({
            assets: 1,
            totalAssets: 1,
            totalShares: 1000,
            rounding: Rounding.UP,
            assetType: ISilo.AssetType.Debt,
            result: 1000
        });
    }

    /*
    forge test -vv --mt test_convertToShares
    */
    function test_convertToShares() public {
        for (uint256 index = 0; index < numberOfTestCases; index++) {
            assertEq(
                SiloMathLib.convertToShares(
                    cases[index].assets,
                    cases[index].totalAssets,
                    cases[index].totalShares,
                    cases[index].rounding,
                    cases[index].assetType
                ),
                cases[index].result,
                string.concat("TestCase: ", Strings.toString(index))
            );
        }
    }
}
