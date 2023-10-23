// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract MaxLiquidationPreviewTestData {
    uint256 constant _BP2DP_NORMALIZATION = 10 ** (18 - 4);
    
    struct Input {
        uint256 totalBorrowerDebtValue;
        uint256 totalBorrowerCollateralValue;
        uint256 ltvAfterLiquidationInDp;
        uint256 liquidityFeeInBp;
    }

    struct Output {
        uint256 collateralValueToLiquidate;
        uint256 repayValue;
        bool targetLtvPossible;
    }

    struct MLPData {
        Input input;
        Output output;
    }

    function readDataFromJson() external pure returns (MLPData[] memory data) {
        data = new MLPData[](6);
        uint256 i;

        // no debt no liquidation
        data[i++] = MLPData({
            input: Input({
                totalBorrowerDebtValue: 0,
                totalBorrowerCollateralValue: 1e18,
                ltvAfterLiquidationInDp: 7000 * _BP2DP_NORMALIZATION,
                liquidityFeeInBp: 500
            }),
            output: Output({
                collateralValueToLiquidate: 0,
                repayValue: 0,
                targetLtvPossible: false
            })
        });

        // when bad debt
        data[i++] = MLPData({
            input: Input({
                totalBorrowerDebtValue: 180e18,
                totalBorrowerCollateralValue: 100e18,
                ltvAfterLiquidationInDp: 7000 * _BP2DP_NORMALIZATION,
                liquidityFeeInBp: 500
            }),
                output: Output({
                collateralValueToLiquidate: 100e18,
                repayValue: 180e18,
                targetLtvPossible: false
            })
        });

        // if we expect ltv to be 0, we need full liquidation
        data[i++] = MLPData({
            input: Input({
                totalBorrowerDebtValue: 80e18,
                totalBorrowerCollateralValue: 100e18,
                ltvAfterLiquidationInDp: 0,
                liquidityFeeInBp: 500
            }),
            output: Output({
                collateralValueToLiquidate: 80e18 + 80e18 * 500 / 1e4,
                repayValue: 80e18,
                targetLtvPossible: true
            })
        });

        // if we over 100% with fee, then we return all
        data[i++] = MLPData({
            input: Input({
                totalBorrowerDebtValue: 98e18,
                totalBorrowerCollateralValue: 100e18,
                ltvAfterLiquidationInDp: 9700 * _BP2DP_NORMALIZATION,
                liquidityFeeInBp: 310
            }),
            output: Output({
                collateralValueToLiquidate: 100e18,
                repayValue: 98e18,
                targetLtvPossible: false
            })
        });

        // if we over 100% with fee, then we return all - COUNTEREXAMPLE
        // but we caught dust, so again full liquidation
        data[i++] = MLPData({
            input: Input({
                totalBorrowerDebtValue: 98e18,
                totalBorrowerCollateralValue: 100e18,
                ltvAfterLiquidationInDp: 9700 * _BP2DP_NORMALIZATION,
                liquidityFeeInBp: 204 // 205-310 all produces collateral over 100%
            }),
            output: Output({ // result is 9791 LTV not 9700, but this are extreme input data
                collateralValueToLiquidate: (98e18 + 98e18 * 204 / 1e4), // 99999200000000000000
                repayValue: 98e18,
                targetLtvPossible: false
            })
        });

        // example from excel simulation
        data[i++] = MLPData({
            input: Input({
                totalBorrowerDebtValue: 80e18,
                totalBorrowerCollateralValue: 100e18,
                ltvAfterLiquidationInDp: 7000 * _BP2DP_NORMALIZATION,
                liquidityFeeInBp: 500
            }),
            output: Output({
                collateralValueToLiquidate: 39622641509433962263,
                repayValue: 37735849056603773584,
                targetLtvPossible: true
            })
        });
    }
}
