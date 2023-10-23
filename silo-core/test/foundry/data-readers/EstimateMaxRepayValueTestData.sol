// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract EstimateMaxRepayValueTestData {
    uint256 constant BP2DP_NORMALIZATION = 10 ** (18-4);

    struct Input {
        uint256 totalBorrowerDebtValue;
        uint256 totalBorrowerCollateralValue;
        uint256 ltvAfterLiquidationInDp;
        uint256 liquidityFeeInBp;
    }

    struct EMRVData {
        Input input;
        uint256 repayValue;
    }

    function readDataFromJson() external pure returns (EMRVData[] memory data) {
        data = new EMRVData[](8);
        uint256 i;

        // no debt no liquidation
        data[i++] = EMRVData({
            input: Input({
                totalBorrowerDebtValue: 0,
                totalBorrowerCollateralValue: 1e18,
                ltvAfterLiquidationInDp: 7000 * BP2DP_NORMALIZATION,
                liquidityFeeInBp: 500
            }),
            repayValue: 0
        });

        // when target LTV higher than current
        data[i++] = EMRVData({
            input: Input({
                totalBorrowerDebtValue: 1e18,
                totalBorrowerCollateralValue: 2e18,
                ltvAfterLiquidationInDp: 5001 * BP2DP_NORMALIZATION,
                liquidityFeeInBp: 500
            }),
            repayValue: 0
        });

        // if BP - LT - LT * f -> negative
        data[i++] = EMRVData({
            input: Input({
                totalBorrowerDebtValue: 80e18,
                totalBorrowerCollateralValue: 100e18,
                ltvAfterLiquidationInDp: 7900 * BP2DP_NORMALIZATION,
                liquidityFeeInBp: 2659
            }),
            repayValue: 80e18 // we repay all because we never get as low as 79%
        });

        // if BP - LT - LT * f -> negative - COUNTER EXAMPLE
        data[i++] = EMRVData({
            input: Input({
                totalBorrowerDebtValue: 80e18,
                totalBorrowerCollateralValue: 100e18,
                ltvAfterLiquidationInDp: 7900 * BP2DP_NORMALIZATION, // impossible to get here with such high fee
                liquidityFeeInBp: 2658
            }),
            repayValue: 80e18
        });

        // when bad debt
        data[i++] = EMRVData({
            input: Input({
                totalBorrowerDebtValue: 180e18,
                totalBorrowerCollateralValue: 180e18,
                ltvAfterLiquidationInDp: 7000 * BP2DP_NORMALIZATION,
                liquidityFeeInBp: 1
            }),
            repayValue: 180e18
        });

        // if we expect ltv to be 0, we need full liquidation
        data[i++] = EMRVData({
            input: Input({
                totalBorrowerDebtValue: 80e18,
                totalBorrowerCollateralValue: 100e18,
                ltvAfterLiquidationInDp: 0 * BP2DP_NORMALIZATION,
                liquidityFeeInBp: 500
            }),
            repayValue: 80e18
        });

        // example from exec simulation
        data[i++] = EMRVData({
            input: Input({
                totalBorrowerDebtValue: 80e18,
                totalBorrowerCollateralValue: 100e18,
                ltvAfterLiquidationInDp: 7000 * BP2DP_NORMALIZATION,
                liquidityFeeInBp: 500
            }),
            repayValue: 37735849056603773584
        });

        // example from exec simulation
        data[i++] = EMRVData({
            input: Input({
                totalBorrowerDebtValue: 80e18,
                totalBorrowerCollateralValue: 112e18,
                ltvAfterLiquidationInDp: 7000 * BP2DP_NORMALIZATION,
                liquidityFeeInBp: 500
            }),
            repayValue: 6037735849056603773
        });
    }
}
