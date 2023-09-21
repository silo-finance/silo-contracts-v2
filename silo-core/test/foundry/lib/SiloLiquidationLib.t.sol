// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../../contracts/lib/SiloLiquidationLib.sol";
import "../_checkedMath/SiloLiquidationLibChecked.sol";
import "../data-readers/CalculateCollateralToLiquidateTestData.sol";
import "../data-readers/CalculateExactLiquidationAmountsTestData.sol";
import "../data-readers/MaxLiquidationPreviewTestData.sol";
import "../data-readers/EstimateMaxRepayValueTestData.sol";


// forge test -vv --mc SiloLiquidationLibTest
contract SiloLiquidationLibTest is Test {
    uint256 internal constant _BASIS_POINTS = 1e4;

    // forge test -vv --mt test_SiloLiquidationLib_minAcceptableLT
    function test_SiloLiquidationLib_minAcceptableLT() public {
        assertEq(SiloLiquidationLib.minAcceptableLT(0), 0);
        assertEq(SiloLiquidationLib.minAcceptableLT(1), 0);
        assertEq(SiloLiquidationLib.minAcceptableLT(10), 9);
        assertEq(SiloLiquidationLib.minAcceptableLT(500), 450);
        assertEq(SiloLiquidationLib.minAcceptableLT(1e4), 9000);

        uint256 gasStart = gasleft();
        assertEq(SiloLiquidationLib.minAcceptableLT(800), 720, "LT=80% => min=>72%");
        uint256 gasEnd = gasleft();

        assertEq(gasStart - gasEnd, 134, "optimise minAcceptableLT()");
    }

    /*
    forge test -vv --mt test_SiloLiquidationLib_collateralToLiquidate
    */
    function test_SiloLiquidationLib_collateralToLiquidate() public {
        // uint256 _debtToCover, uint256 _totalCollateral, uint256 _liquidityFeeInBp
        assertEq(SiloLiquidationLib.collateralToLiquidate(0, 0, 0), 0);
        assertEq(SiloLiquidationLib.collateralToLiquidate(1, 1, 0), 1);
        assertEq(SiloLiquidationLib.collateralToLiquidate(1, 1, 1), 1);
        assertEq(SiloLiquidationLib.collateralToLiquidate(10, 10, 999), 10);
        assertEq(SiloLiquidationLib.collateralToLiquidate(10, 11, 1000), 11);
        assertEq(SiloLiquidationLib.collateralToLiquidate(10, 9, 1000), 9);
        assertEq(SiloLiquidationLib.collateralToLiquidate(100, 1000, 1200), 112);
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

            assertEq(collateralAssets, data[i].output.collateralAssets, "expect collateralAssets");
            assertEq(collateralValue, data[i].output.collateralValue, "expect collateralValue");
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
                data[i].input.totalBorrowerDebtValue,
                data[i].input.totalBorrowerDebtAssets,
                data[i].input.totalBorrowerCollateralValue,
                data[i].input.totalBorrowerCollateralAssets,
                data[i].input.liquidationFee
            );

            // emit log_named_uint("#", i);
            assertEq(collateralAssetsToLiquidate, data[i].output.collateralAssetsToLiquidate, "expect assets");
            assertEq(debtAssetsToRepay, data[i].output.debtAssetsToRepay, "expect debtAssetsToRepay");
            assertEq(ltvAfterLiquidation, data[i].output.ltvAfterLiquidation, "expect ltvAfterLiquidation");
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
                data[i].input.ltvAfterLiquidationInBp,
                data[i].input.liquidityFeeInBp
            );

            // emit log_named_uint("#", i);
            assertEq(repayValue, data[i].repayValue, "expect repayValue");
        }
    }

    /*
    forge test -vv --mt test_SiloLiquidationLib_estimateMaxRepayValue_raw
    */
    function test_SiloLiquidationLib_estimateMaxRepayValue_raw() public {
        // debtValue, CollateralValue, ltv, fee
        assertEq(
            SiloLiquidationLib.estimateMaxRepayValue(1e18, 1e18, 80, 10),
            _estimateMaxRepayValueRaw(1e18, 1e18, 80, 10),
            "expect raw == estimateMaxRepayValue"
        );

        // simulation values
        assertEq(
            SiloLiquidationLib.estimateMaxRepayValue(85e18, 100e18, 7900, 300),
            _estimateMaxRepayValueRaw(85e18, 100e18, 7900, 300),
            "expect raw == estimateMaxRepayValue"
        );

        // simulation values
        assertEq(
            SiloLiquidationLib.estimateMaxRepayValue(85e18, 111e18, 5000, 1000),
            _estimateMaxRepayValueRaw(85e18, 111e18, 5000, 1000),
            "expect raw == estimateMaxRepayValue"
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
                data[i].input.totalBorrowerDebtValue,
                data[i].input.totalBorrowerCollateralValue,
                data[i].input.ltvAfterLiquidationInBp,
                data[i].input.liquidityFeeInBp
            );

            assertEq(collateralValueToLiquidate, data[i].output.collateralValueToLiquidate, "expect collateral value");
            assertEq(repayValue, data[i].output.repayValue, "expect repayValue");

            // cross check, but only when totalBorrowerDebtValue > 0
            // otherwise we will have different results for ltv because ltvAfterLiquidationInBp will not be achievable

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
                data[i].input.totalBorrowerDebtValue,
                totalBorrowerDebtAssets,
                data[i].input.totalBorrowerCollateralValue,
                totalBorrowerCollateralAssets,
                data[i].input.liquidityFeeInBp
            );

            // emit log_named_uint("cross check #", i);

            if (data[i].output.targetLtvPossible) {
                assertEq(ltvAfterLiquidation, data[i].input.ltvAfterLiquidationInBp, "ltvAfterLiquidation cross check");
            } else {
                assertEq(ltvAfterLiquidation, 0, "ltvAfterLiquidation cross check");
            }

            // calculateExactLiquidationAmounts VS maxLiquidationPreview
            assertEq(collateralAssetsToLiquidate / 3, collateralValueToLiquidate, "collateral cross check");
            assertEq(debtAssetsToRepay / 2, repayValue, "debt cross check");
        }
    }

    /*
    forge test -vv --mt test_SiloLiquidationLib_calculateCollateralToLiquidate_math
    */
    function test_SiloLiquidationLib_calculateCollateralToLiquidate_math(
        uint256 _debtToCover,
        uint128 _totalBorrowerDebtAssets,
        uint128 _totalBorrowerCollateralAssets,
        uint256 _liquidationFeeInBp,
        uint16 _quote
    ) public {
        vm.assume(_liquidationFeeInBp <= 1e3);
        vm.assume(_debtToCover <= _totalBorrowerDebtAssets);
        vm.assume(_totalBorrowerDebtAssets > 0);
        vm.assume(_totalBorrowerCollateralAssets > 0);

        vm.assume(_quote > 0);

        uint256 totalBorrowerDebtValue = _totalBorrowerDebtAssets;
        uint256 totalBorrowerCollateralValue = _totalBorrowerCollateralAssets;

        // just ro randomise
        if (_quote % 2 == 0) {
            totalBorrowerDebtValue *= _quote;
        } else {
            totalBorrowerCollateralValue *= _quote;
        }

        // we assume here, we are under 100% of ltv, otherwise it is full liquidation
        vm.assume(totalBorrowerDebtValue * _BASIS_POINTS / totalBorrowerCollateralValue <= _BASIS_POINTS);

        (
            uint256 collateralAssetsToLiquidate, uint256 debtAssetsToRepay,
        ) = SiloLiquidationLib.calculateExactLiquidationAmounts(
            _debtToCover,
            totalBorrowerDebtValue,
            _totalBorrowerDebtAssets,
            totalBorrowerCollateralValue,
            _totalBorrowerDebtAssets,
            _liquidationFeeInBp
        );

        (
            uint256 collateralAssetsToLiquidate2, uint256 debtAssetsToRepay2,
        ) = SiloLiquidationLibChecked.calculateExactLiquidationAmounts(
            _debtToCover,
            totalBorrowerDebtValue,
            _totalBorrowerDebtAssets,
            totalBorrowerCollateralValue,
            _totalBorrowerDebtAssets,
            _liquidationFeeInBp
        );

        assertEq(collateralAssetsToLiquidate2, collateralAssetsToLiquidate, "collateralAssetsToLiquidate");
        assertEq(debtAssetsToRepay2, debtAssetsToRepay, "debtAssetsToRepay");
        // not testing ltv because stack to deep, but if others two values are good, we good on ltv
        // assertEq(ltvAfterLiquidationInBp2, ltvAfterLiquidationInBp, "ltvAfterLiquidationInBp");
    }

    /*
    forge test -vv --mt test_SiloLiquidationLib_calculateExactLiquidationAmounts_not_reverts
    */
    function test_SiloLiquidationLib_calculateExactLiquidationAmounts_not_reverts() public {
        SiloLiquidationLib.calculateExactLiquidationAmounts(0, 0, 1e18, 1e18, 0, 0);
        SiloLiquidationLib.calculateExactLiquidationAmounts(1, 1e18, 0, 1e18, 0, 0);
        SiloLiquidationLib.calculateExactLiquidationAmounts(0, 1e18, 1e18, 0, 0, 0);
        SiloLiquidationLib.calculateExactLiquidationAmounts(1, 1e18, 1e18, 0, 0, 0);

        uint256 gasStart = gasleft();
        SiloLiquidationLib.calculateExactLiquidationAmounts(1e8, 1e18, 1e18, 1e18, 1e18, 10);
        uint256 gasEnd = gasleft();

        assertEq(gasStart - gasEnd, 1168, "optimise calculateExactLiquidationAmounts");
    }

    /*
    forge test -vv --mt test_SiloLiquidationLib_calculateCollateralToLiquidate_not_reverts
    */
    function test_SiloLiquidationLib_calculateCollateralToLiquidate_not_reverts() public {
        uint256 debtValueToCover = 2e18;
        uint256 totalBorrowerCollateralValue = 20e18; // price is 2 per asset
        uint256 totalBorrowerCollateralAssets = 10e18;
        uint256 liquidationFee = 100; // 1%

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

        assertEq(gasStart - gasEnd, 562, "optimise calculateCollateralToLiquidate()");
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

        (fromCollateral, fromProtected) = SiloLiquidationLib.splitReceiveCollateralToLiquidate(5, 15);
        assertEq(fromCollateral, 0, "fromCollateral (5, 15) => 0");
        assertEq(fromProtected, 5, "fromProtected (5, 15) => 5");
    }
    
    // forge test -vv --mt test_SiloLiquidationLib_maxLiquidationPreview_unchecked_fuzz
    function test_SiloLiquidationLib_maxLiquidationPreview_unchecked_fuzz(
        uint128 _debtAmount,
        uint128 _collateralAmount,
        uint16 _targetLT,
        uint16 _liquidityFee
    ) public {
        vm.assume(_targetLT <= 1e4);
        vm.assume(_liquidityFee <= 1e3);

        // prices here are arbitrary
        uint256 debtValue = uint256(_debtAmount) * 50_000;
        uint256 collateralValue = uint256(_collateralAmount) * 80_000;

        (uint256 repayValue, uint256 receiveCollateral) = SiloLiquidationLib.maxLiquidationPreview(
            debtValue,
            collateralValue,
            uint256(_targetLT),
            uint256(_liquidityFee)
        );

        emit log_string("SiloLiquidationLib.calculateLiquidationValues PASS");

        (
            uint256 repayValue2, uint256 receiveCollateral2
        ) = SiloLiquidationLibChecked.maxLiquidationPreview(
            debtValue, collateralValue, _targetLT, _liquidityFee
        );

        assertEq(repayValue, repayValue2, "repay must match value with safe math");
        assertEq(receiveCollateral, receiveCollateral2, "receiveCollateral must match value with safe math");
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

    /// @dev the math is based on: (Dv - x)/(Cv - (x + xf)) = LT
    /// where Dv: debt value, Cv: collateral value, LT: expected LT, f: liquidation fee, x: is value we looking for
    /// x = (Dv - LT * Cv) / (BP - LT - LT * f)
    function _estimateMaxRepayValueRaw(
        uint256 _totalBorrowerDebtValue,
        uint256 _totalBorrowerCollateralValue,
        uint256 _ltvAfterLiquidationInBp,
        uint256 _liquidityFeeInBp
    )
        private pure returns (uint256 repayValue)
    {
        return (_totalBorrowerDebtValue - _ltvAfterLiquidationInBp * _totalBorrowerCollateralValue / _BASIS_POINTS) *
            _BASIS_POINTS /
            (_BASIS_POINTS - _ltvAfterLiquidationInBp - _ltvAfterLiquidationInBp * _liquidityFeeInBp / _BASIS_POINTS);
    }
}
