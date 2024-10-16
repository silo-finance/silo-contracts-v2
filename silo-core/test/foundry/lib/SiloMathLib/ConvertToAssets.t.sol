// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";

import {SiloMathLib, ISilo, Math} from "silo-core/contracts/lib/SiloMathLib.sol";
import {Rounding} from "silo-core/contracts/lib/Rounding.sol";

// forge test -vv --mc ConvertToAssetsTest
contract ConvertToAssetsTest is Test {
    struct TestCase {
        uint256 shares;
        uint256 totalAssets;
        uint256 totalShares;
        Math.Rounding rounding;
        ISilo.AssetType assetType;
        uint256 result;
    }

    uint256 public numberOfTestCases = 20;

    mapping(uint256 => TestCase) public cases;

    function setUp() public {
        cases[0] = TestCase({
            shares: 0,
            totalAssets: 0,
            totalShares: 0,
            rounding: Rounding.DOWN,
            assetType: ISilo.AssetType.Collateral,
            result: 0
        });

        cases[1] = TestCase({
            shares: 10000,
            totalAssets: 0,
            totalShares: 0,
            rounding: Rounding.DOWN,
            assetType: ISilo.AssetType.Collateral,
            result: 10
        });

        cases[2] = TestCase({
            shares: 333333,
            totalAssets: 1000,
            totalShares: 999000,
            rounding: Rounding.DOWN,
            assetType: ISilo.AssetType.Collateral,
            result: 333
        });

        cases[3] = TestCase({
            shares: 333000,
            totalAssets: 1000,
            totalShares: 999000,
            rounding: Rounding.UP,
            assetType: ISilo.AssetType.Collateral,
            result: 334
        });

        cases[4] = TestCase({
            shares: 333000,
            totalAssets: 1000,
            totalShares: 1000000,
            rounding: Rounding.DOWN,
            assetType: ISilo.AssetType.Collateral,
            result: 333
        });

        cases[5] = TestCase({
            shares: 333000,
            totalAssets: 1000,
            totalShares: 1000000,
            rounding: Rounding.DOWN,
            assetType: ISilo.AssetType.Collateral,
            result: 333
        });

        cases[6] = TestCase({
            shares: 1000,
            totalAssets: 1000,
            totalShares: 1000,
            rounding: Rounding.DOWN,
            assetType: ISilo.AssetType.Collateral,
            result: 500
        });

        cases[7] = TestCase({
            shares: 1000,
            totalAssets: 1000,
            totalShares: 1000,
            rounding: Rounding.UP,
            assetType: ISilo.AssetType.Collateral,
            result: 501
        });

        cases[8] = TestCase({
            shares: 1000,
            totalAssets: 1000,
            totalShares: 10000,
            rounding: Rounding.DOWN,
            assetType: ISilo.AssetType.Collateral,
            result: 91
        });

        cases[9] = TestCase({
            shares: 0,
            totalAssets: 0,
            totalShares: 0,
            rounding: Rounding.DOWN,
            assetType: ISilo.AssetType.Debt,
            result: 0
        });

        cases[10] = TestCase({
            shares: 10,
            totalAssets: 0,
            totalShares: 0,
            rounding: Rounding.DOWN,
            assetType: ISilo.AssetType.Debt,
            result: 10
        });

        cases[11] = TestCase({
            shares: 333000,
            totalAssets: 1000,
            totalShares: 999000,
            rounding: Rounding.DOWN,
            assetType: ISilo.AssetType.Debt,
            result: 333
        });

        cases[12] = TestCase({
            shares: 333000,
            totalAssets: 1000,
            totalShares: 999000,
            rounding: Rounding.UP,
            assetType: ISilo.AssetType.Debt,
            result: 334
        });

        cases[13] = TestCase({
            shares: 333000,
            totalAssets: 1000,
            totalShares: 1000000,
            rounding: Rounding.DOWN,
            assetType: ISilo.AssetType.Debt,
            result: 333
        });

        cases[14] = TestCase({
            shares: 333000,
            totalAssets: 1000,
            totalShares: 1000000,
            rounding: Rounding.DOWN,
            assetType: ISilo.AssetType.Debt,
            result: 333
        });

        cases[15] = TestCase({
            shares: 1000,
            totalAssets: 1000,
            totalShares: 1000,
            rounding: Rounding.DOWN,
            assetType: ISilo.AssetType.Debt,
            result: 1000
        });

        cases[16] = TestCase({
            shares: 1000,
            totalAssets: 1000,
            totalShares: 1000,
            rounding: Rounding.UP,
            assetType: ISilo.AssetType.Debt,
            result: 1000
        });

        cases[17] = TestCase({
            shares: 1,
            totalAssets: 1000,
            totalShares: 10,
            rounding: Rounding.DOWN,
            assetType: ISilo.AssetType.Debt,
            result: 100
        });

        cases[18] = TestCase({
            shares: 1,
            totalAssets: 1000,
            totalShares: 10,
            rounding: Rounding.UP,
            assetType: ISilo.AssetType.Debt,
            result: 100
        });
    }

    /*
    forge test -vv --mt test_convertToAssets
    */
    function test_convertToAssets() public view {
        for (uint256 index = 0; index < numberOfTestCases; index++) {
            assertEq(
                SiloMathLib.convertToAssets(
                    cases[index].shares,
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
