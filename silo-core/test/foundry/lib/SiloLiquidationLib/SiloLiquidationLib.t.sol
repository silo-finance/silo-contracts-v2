// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {Strings} from "openzeppelin-contracts/utils/Strings.sol";

import "silo-core/contracts/lib/SiloLiquidationLib.sol";

import "../../_checkedMath/SiloLiquidationLibChecked.sol";
import "../../data-readers/CalculateCollateralToLiquidateTestData.sol";
import "../../data-readers/CalculateExactLiquidationAmountsTestData.sol";
import "../../data-readers/MaxLiquidationPreviewTestData.sol";
import "../../data-readers/EstimateMaxRepayValueTestData.sol";
import "./MaxRepayRawMath.sol";


// forge test -vv --mc SiloLiquidationLibTest
contract SiloLiquidationLibTest is Test, MaxRepayRawMath {
    uint256 internal constant _DECIMALS_POINTS = 1e18;

    /*
    forge test -vv --mt test_SiloLiquidationLib_minAcceptableLTV
    */
    function test_SiloLiquidationLib_minAcceptableLTV() public {
        assertEq(SiloLiquidationLib.minAcceptableLTV(0), 0);
        assertEq(SiloLiquidationLib.minAcceptableLTV(1), 0);
        assertEq(SiloLiquidationLib.minAcceptableLTV(10), 9);
        assertEq(SiloLiquidationLib.minAcceptableLTV(500), 450);
        assertEq(SiloLiquidationLib.minAcceptableLTV(1e4), 9000);

        uint256 gasStart = gasleft();
        assertEq(SiloLiquidationLib.minAcceptableLTV(800), 720, "LT=80% => min=>72%");
        uint256 gasEnd = gasleft();

        assertEq(gasStart - gasEnd, 134, "optimise minAcceptableLTV()");
    }

    /*
    forge test -vv --mt test_SiloLiquidationLib_collateralToLiquidate
    */
    function test_SiloLiquidationLib_collateralToLiquidate() public {
        // uint256 _debtToCover, uint256 _totalCollateral, uint256 _liquidityFee
        assertEq(SiloLiquidationLib.calculateCollateralToLiquidate(0, 0, 0), 0);
        assertEq(SiloLiquidationLib.calculateCollateralToLiquidate(1, 1, 0), 1);
        assertEq(SiloLiquidationLib.calculateCollateralToLiquidate(1, 1, 0.0001e18), 1);
        assertEq(SiloLiquidationLib.calculateCollateralToLiquidate(10, 10, 0.0999e18), 10);
        assertEq(SiloLiquidationLib.calculateCollateralToLiquidate(10, 11, 0.1e18), 11);
        assertEq(SiloLiquidationLib.calculateCollateralToLiquidate(10, 9, 0.1e18), 9);
        assertEq(SiloLiquidationLib.calculateCollateralToLiquidate(100, 1000, 0.12e18), 112);
    }

    /*
    forge test -vv --mt test_SiloLiquidationLib_calculateCollateralToLiquidate_pass
    */
    function test_SiloLiquidationLib_calculateCollateralToLiquidate_pass() public {
        CalculateCollateralToLiquidateTestData json = new CalculateCollateralToLiquidateTestData();
        CalculateCollateralToLiquidateTestData.CCTLData[] memory data = json.readDataFromJson();

        assertGe(data.length, 4, "expect to have tests");

        for (uint256 i; i < data.length; i++) {
            (
                uint256 collateralAssets,
                uint256 collateralValue
            ) = SiloLiquidationLib.calculateCollateralsToLiquidate(
                data[i].input.debtValueToCover,
                data[i].input.totalBorrowerCollateralValue,
                data[i].input.totalBorrowerCollateralAssets,
                data[i].input.liquidationFee
            );

            assertEq(collateralAssets, data[i].output.collateralAssets, _concatMsg(i, "expect collateralAssets"));
            assertEq(collateralValue, data[i].output.collateralValue, _concatMsg(i, "expect collateralValue"));
        }
    }


    /*
    forge test -vv --mt test_SiloLiquidationLib_calculateExactLiquidationAmounts_pass
    */
    function test_SiloLiquidationLib_calculateExactLiquidationAmounts_pass() public {
        CalculateExactLiquidationAmountsTestData json = new CalculateExactLiquidationAmountsTestData();
        CalculateExactLiquidationAmountsTestData.CELAData[] memory data = json.readDataFromJson();

        assertGe(data.length, 1, "expect to have tests");

        for (uint256 i; i < data.length; i++) {
            (
                uint256 collateralAssetsToLiquidate,
                uint256 debtAssetsToRepay,
                uint256 ltvAfterLiquidation
            ) = SiloLiquidationLib.calculateExactLiquidationAmounts(
                data[i].input.debtToCover,
                data[i].input.totalBorrowerCollateralAssets,
                data[i].input.totalBorrowerCollateralValue,
                data[i].input.totalBorrowerDebtAssets,
                data[i].input.totalBorrowerDebtValue,
                data[i].input.liquidationFee
            );

            assertEq(
                collateralAssetsToLiquidate, data[i].output.collateralAssetsToLiquidate,
                _concatMsg(i, "] output.collateralAssetsToLiquidate")
            );
            assertEq(
                debtAssetsToRepay, data[i].output.debtAssetsToRepay, _concatMsg(i, "] expect debtAssetsToRepay")
            );
            assertEq(
                ltvAfterLiquidation, data[i].output.ltvAfterLiquidation, _concatMsg(i, "] expect ltvAfterLiquidation")
            );
        }
    }

    /*
    forge test -vv --mt test_SiloLiquidationLib_estimateMaxRepayValue_pass
    */
    function test_SiloLiquidationLib_estimateMaxRepayValue_pass() public {
        EstimateMaxRepayValueTestData json = new EstimateMaxRepayValueTestData();
        EstimateMaxRepayValueTestData.EMRVData[] memory data = json.readDataFromJson();

        assertGe(data.length, 1, "expect to have tests");

        for (uint256 i; i < data.length; i++) {
            uint256 repayValue = SiloLiquidationLib.estimateMaxRepayValue(
                data[i].input.totalBorrowerDebtValue,
                data[i].input.totalBorrowerCollateralValue,
                data[i].input.ltvAfterLiquidation,
                data[i].input.liquidityFee
            );

            console.log("repayValue %s", repayValue);
            assertEq(repayValue, data[i].repayValue, _concatMsg(i, "expect repayValue"));
        }
    }

    /*
    forge test -vv --mt test_SiloLiquidationLib_estimateMaxRepayValue_raw
    */
    function test_SiloLiquidationLib_estimateMaxRepayValue_raw() public {
        // debtValue, CollateralValue, ltv, fee
        assertEq(
            SiloLiquidationLib.estimateMaxRepayValue(1e18, 1e18, 0.0080e18, 0.0010e18),
            _estimateMaxRepayValueRaw(1e18, 1e18, 0.0080e18, 0.0010e18),
            "expect raw == estimateMaxRepayValue (1)"
        );

        // simulation values
        assertEq(
            SiloLiquidationLib.estimateMaxRepayValue(85e18, 1e18, 0.79e18, 0.03e18),
            _estimateMaxRepayValueRaw(85e18, 1e18, 0.79e18, 0.03e18),
            "expect raw == estimateMaxRepayValue (2)"
        );

        // simulation values
        assertEq(
            SiloLiquidationLib.estimateMaxRepayValue(85e18, 111e18, 0.5e18, 0.1e18),
            _estimateMaxRepayValueRaw(85e18, 111e18, 0.5e18, 0.1e18),
            "expect raw == estimateMaxRepayValue (3)"
        );
    }

    /*
    forge test -vv --mt test_SiloLiquidationLib_maxLiquidationPreview_pass
    */
    function test_SiloLiquidationLib_maxLiquidationPreview_pass() public {
        MaxLiquidationPreviewTestData json = new MaxLiquidationPreviewTestData();
        MaxLiquidationPreviewTestData.MLPData[] memory data = json.readDataFromJson();

        assertGe(data.length, 1, "expect to have tests");

        for (uint256 i; i < data.length; i++) {
            (
                uint256 collateralValueToLiquidate,
                uint256 repayValue
            ) = SiloLiquidationLib.maxLiquidationPreview(
                data[i].input.totalBorrowerCollateralValue,
                data[i].input.totalBorrowerDebtValue,
                data[i].input.ltvAfterLiquidation,
                data[i].input.liquidityFee
            );

            assertEq(
                collateralValueToLiquidate, data[i].output.collateralValueToLiquidate,
                _concatMsg(i, "expect collateral value")
            );
            assertEq(repayValue, data[i].output.repayValue, _concatMsg(i, "expect repayValue"));

            // cross check, but only when totalBorrowerDebtValue > 0
            // otherwise we will have different results for ltv because ltvAfterLiquidation will not be achievable

            // assets does not matter because it is basically related to value by price
            // so I pick here some arbitrary prices
            uint256 totalBorrowerDebtAssets = data[i].input.totalBorrowerDebtValue * 2;
            uint256 totalBorrowerCollateralAssets = data[i].input.totalBorrowerCollateralValue * 3;

            (
                uint256 collateralAssetsToLiquidate,
                uint256 debtAssetsToRepay,
                uint256 ltvAfterLiquidation
            ) = SiloLiquidationLib.calculateExactLiquidationAmounts(
                _assetsChunk(data[i].input.totalBorrowerDebtValue, totalBorrowerDebtAssets, repayValue),
                totalBorrowerCollateralAssets,
                data[i].input.totalBorrowerCollateralValue,
                totalBorrowerDebtAssets,
                data[i].input.totalBorrowerDebtValue,
                data[i].input.liquidityFee
            );

            // emit log_named_uint("cross check #", i);

            if (data[i].output.targetLtvPossible) {
                assertEq(
                    ltvAfterLiquidation, data[i].input.ltvAfterLiquidation,
                    _concatMsg(i, "ltvAfterLiquidation cross check")
                );
            } else {
                assertEq(ltvAfterLiquidation, 0, _concatMsg(i, "ltvAfterLiquidation cross check"));
            }

            // calculateExactLiquidationAmounts VS maxLiquidationPreview
            assertEq(
                collateralAssetsToLiquidate / 3, collateralValueToLiquidate, _concatMsg(i, "collateral cross check")
            );
            assertEq(debtAssetsToRepay / 2, repayValue, _concatMsg(i, "debt cross check"));
        }
    }

    /*
    forge test -vv --mt test_SiloLiquidationLib_calculateCollateralToLiquidate_math
    */
    function test_SiloLiquidationLib_calculateCollateralToLiquidate_math_fuzz(
        uint256 _debtToCover,
        uint128 _totalBorrowerDebtAssets,
        uint128 _totalBorrowerCollateralAssets,
        uint256 _liquidationFee,
        uint16 _quote
    ) public {
        vm.assume(_liquidationFee <= 0.1e18);
        vm.assume(_debtToCover <= _totalBorrowerDebtAssets);
        vm.assume(_totalBorrowerDebtAssets > 0);
        vm.assume(_totalBorrowerCollateralAssets > 0);
        vm.assume(_quote > 0);
        vm.assume(_totalBorrowerDebtAssets < type(uint128).max / _quote);
        vm.assume(_totalBorrowerCollateralAssets < type(uint128).max / _quote);

        uint256 totalBorrowerDebtValue = _totalBorrowerDebtAssets;
        uint256 totalBorrowerCollateralValue = _totalBorrowerCollateralAssets;

        // just ro randomise
        if (_quote % 2 == 0) {
            totalBorrowerDebtValue *= _quote;
        } else {
            totalBorrowerCollateralValue *= _quote;
        }

        // we assume here, we are under 100% of ltv, otherwise it is full liquidation
        vm.assume(totalBorrowerDebtValue * _DECIMALS_POINTS / totalBorrowerCollateralValue <= _DECIMALS_POINTS);

        (
            uint256 collateralAssetsToLiquidate, uint256 debtAssetsToRepay,
        ) = SiloLiquidationLib.calculateExactLiquidationAmounts(
            _debtToCover,
            _totalBorrowerCollateralAssets,
            totalBorrowerCollateralValue,
            _totalBorrowerDebtAssets,
            totalBorrowerDebtValue,
            _liquidationFee
        );

        (
            uint256 collateralAssetsToLiquidate2, uint256 debtAssetsToRepay2,
        ) = SiloLiquidationLibChecked.calculateExactLiquidationAmounts(
            _debtToCover,
            _totalBorrowerCollateralAssets,
            totalBorrowerCollateralValue,
            _totalBorrowerDebtAssets,
            totalBorrowerDebtValue,
            _liquidationFee
        );

        assertEq(collateralAssetsToLiquidate2, collateralAssetsToLiquidate, "collateralAssetsToLiquidate");
        assertEq(debtAssetsToRepay2, debtAssetsToRepay, "debtAssetsToRepay");
        // not testing ltv because stack to deep, but if others two values are good, we good on ltv
        // assertEq(ltvAfterLiquidation2, ltvAfterLiquidation, "ltvAfterLiquidation");
    }

    /*
    forge test -vv --mt test_SiloLiquidationLib_calculateExactLiquidationAmounts_not_reverts
    */
    function test_SiloLiquidationLib_calculateExactLiquidationAmounts_not_reverts() public {
        SiloLiquidationLib.calculateExactLiquidationAmounts(0, 0, 1e18, 1e18, 0, 0);
        SiloLiquidationLib.calculateExactLiquidationAmounts(1, 0, 1e18, 0, 1e18, 0);
        SiloLiquidationLib.calculateExactLiquidationAmounts(0, 0, 0, 1e18, 1e18, 0);
        SiloLiquidationLib.calculateExactLiquidationAmounts(1, 0, 0, 1e18, 1e18, 0);

        uint256 gasStart = gasleft();
        SiloLiquidationLib.calculateExactLiquidationAmounts(1e8, 1e18, 1e18, 1e18, 1e18, 10);
        uint256 gasEnd = gasleft();

        assertEq(gasStart - gasEnd, 1297, "optimise calculateExactLiquidationAmounts");
    }

    /*
    forge test -vv --mt test_SiloLiquidationLib_calculateCollateralToLiquidate_not_reverts
    */
    function test_SiloLiquidationLib_calculateCollateralToLiquidate_not_reverts() public {
        uint256 debtValueToCover = 2e18;
        uint256 totalBorrowerCollateralValue = 20e18; // price is 2 per asset
        uint256 totalBorrowerCollateralAssets = 10e18;
        uint256 liquidationFee = 0.01e18; // 1%

        SiloLiquidationLib.calculateCollateralsToLiquidate(
            debtValueToCover, 0, totalBorrowerCollateralAssets, liquidationFee
        );

        // counter example without zero
        uint256 gasStart = gasleft();
        (
            uint256 collateralAssetsToLiquidate,
            uint256 collateralValueToLiquidate
        ) = SiloLiquidationLib.calculateCollateralsToLiquidate(
            debtValueToCover, totalBorrowerCollateralValue, totalBorrowerCollateralAssets, liquidationFee
        );
        uint256 gasEnd = gasleft();

        assertEq(gasStart - gasEnd, 558, "optimise calculateCollateralToLiquidate()");
        assertEq(collateralAssetsToLiquidate, 1010000000000000000);
        assertEq(collateralValueToLiquidate, 2020000000000000000);
    }

    /*
    forge test -vv --mt test_SiloLiquidationLib_splitReceiveCollateralToLiquidate
    */
    function test_SiloLiquidationLib_splitReceiveCollateralToLiquidate() public {
        (uint256 fromCollateral, uint256 fromProtected) = SiloLiquidationLib.splitReceiveCollateralToLiquidate(0, 0);
        assertEq(fromCollateral, 0, "fromCollateral (0,0) => 0");
        assertEq(fromProtected, 0, "fromProtected (0,0) => 0");

        (fromCollateral, fromProtected) = SiloLiquidationLib.splitReceiveCollateralToLiquidate(1, 0);
        assertEq(fromCollateral, 1, "fromCollateral (1,0) => 1");
        assertEq(fromProtected, 0, "fromProtected (1,0) => 0");

        (fromCollateral, fromProtected) = SiloLiquidationLib.splitReceiveCollateralToLiquidate(0, 10);
        assertEq(fromCollateral, 0, "fromCollateral (0, 10) => 0");
        assertEq(fromProtected, 0, "fromProtected (0, 10) => 0");

        (fromCollateral, fromProtected) = SiloLiquidationLib.splitReceiveCollateralToLiquidate(10, 2);
        assertEq(fromCollateral, 8, "fromCollateral (10, 2) => 8");
        assertEq(fromProtected, 2, "fromProtected (10, 2) => 2");

        uint256 gasStart = gasleft();
        (fromCollateral, fromProtected) = SiloLiquidationLib.splitReceiveCollateralToLiquidate(5, 15);
        uint256 gasEnd = gasleft();

        assertEq(fromCollateral, 0, "fromCollateral (5, 15) => 0");
        assertEq(fromProtected, 5, "fromProtected (5, 15) => 5");
        assertEq(gasStart - gasEnd, 149, "optimise splitReceiveCollateralToLiquidate");
    }
    
    /*
     forge test -vv --mt test_SiloLiquidationLib_maxLiquidationPreview_unchecked_fuzz
    */
    function test_SiloLiquidationLib_maxLiquidationPreview_unchecked_fuzz(
        uint128 _debtAmount,
        uint128 _collateralAmount,
        uint16 _targetLT,
        uint16 _liquidityFee
    ) public {
        vm.assume(_targetLT <= 1e18);
        vm.assume(_liquidityFee <= 1e18);

        // prices here are arbitrary
        uint256 debtValue = uint256(_debtAmount) * 50_000;
        uint256 collateralValue = uint256(_collateralAmount) * 80_000;

        (uint256 repayValue, uint256 receiveCollateral) = SiloLiquidationLib.maxLiquidationPreview(
            collateralValue,
            debtValue,
            uint256(_targetLT),
            uint256(_liquidityFee)
        );

        emit log_string("SiloLiquidationLib.calculateLiquidationValues PASS");

        (
            uint256 repayValue2, uint256 receiveCollateral2
        ) = SiloLiquidationLibChecked.maxLiquidationPreview(
            collateralValue, debtValue, _targetLT, _liquidityFee
        );

        assertEq(repayValue, repayValue2, "repay must match value with safe math");
        assertEq(receiveCollateral, receiveCollateral2, "receiveCollateral must match value with safe math");
    }

    /*
    forge test -vv --mt test_valueToAssetsByRatio
    */
    function test_valueToAssetsByRatio() public {
        uint256 value;
        uint256 totalAssets;
        uint256 totalValue = 1; // can not be 0

        assertEq(SiloLiquidationLib.valueToAssetsByRatio(value, totalAssets, totalValue), 0);

        value; totalAssets = 1; totalValue = 1;
        assertEq(SiloLiquidationLib.valueToAssetsByRatio(value, totalAssets, totalValue), 0);

        value = 1; totalAssets = 1; totalValue = 1;
        assertEq(SiloLiquidationLib.valueToAssetsByRatio(value, totalAssets, totalValue), 1);

        value = 1; totalAssets = 100; totalValue = 1;
        assertEq(SiloLiquidationLib.valueToAssetsByRatio(value, totalAssets, totalValue), 100);

        value = 1; totalAssets = 100; totalValue = 10;
        assertEq(SiloLiquidationLib.valueToAssetsByRatio(value, totalAssets, totalValue), 10);

        value = 1; totalAssets = 100; totalValue = 100;
        assertEq(SiloLiquidationLib.valueToAssetsByRatio(value, totalAssets, totalValue), 1);

        value = 2; totalAssets = 10; totalValue = 100;
        assertEq(SiloLiquidationLib.valueToAssetsByRatio(value, totalAssets, totalValue), 0);

        value = 2; totalAssets = 1000; totalValue = 100;
        assertEq(SiloLiquidationLib.valueToAssetsByRatio(value, totalAssets, totalValue), 20);
    }

    function _assetsChunk(uint256 _totalValue, uint256 _totalAssets, uint256 _chunkValue)
        private
        pure
        returns (uint256 _chunkAssets)
    {
        if (_totalValue == 0) return 0;

        _chunkAssets = _chunkValue * _totalAssets;
        unchecked { _chunkAssets /= _totalValue; }
    }

    function _concatMsg(uint256 _i, string memory _msg) internal pure returns (string memory) {
        return string.concat("[", Strings.toString(_i), "] ", _msg);
    }
}
