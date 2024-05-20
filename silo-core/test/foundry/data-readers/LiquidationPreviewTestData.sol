// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract LiquidationPreviewTestData {
    struct Input {
        uint256 lt;
        uint256 debtToCover;
        uint256 totalBorrowerDebtValue;
        uint256 totalBorrowerDebtAssets;
        uint256 totalBorrowerCollateralValue;
        uint256 totalBorrowerCollateralAssets;
        uint256 liquidationFee;
    }

    struct Output {
        uint256 collateralAssetsToLiquidate;
        uint256 debtAssetsToRepay;
        uint256 ltvAfterLiquidation;
    }

    struct CELAData {
        Input input;
        Output output;
    }

    function readDataFromJson() external pure returns (CELAData[] memory data) {
        data = new CELAData[](13);
        uint256 i;

        data[i++] = CELAData({ // #0
            input: Input({
                lt: 1,
                debtToCover: 0,
                totalBorrowerDebtValue: 1,
                totalBorrowerDebtAssets: 1,
                totalBorrowerCollateralValue: 1,
                totalBorrowerCollateralAssets: 1,
                liquidationFee: 0
            }),
            output: Output({ // FULL liquidation forced
                collateralAssetsToLiquidate: 0,
                debtAssetsToRepay: 0,
                ltvAfterLiquidation: 1e18
            })
        });

        data[i++] = CELAData({ // #1
            input: Input({
                lt: 1,
                debtToCover: 0,
                totalBorrowerDebtValue: 1,
                totalBorrowerDebtAssets: 1,
                totalBorrowerCollateralValue: 1,
                totalBorrowerCollateralAssets: 1,
                liquidationFee: 0.1e18
            }),
            output: Output({
                collateralAssetsToLiquidate: 0,
                debtAssetsToRepay: 0,
                ltvAfterLiquidation: 1e18
            })
        });

        data[i++] = CELAData({ // #2
            input: Input({
                lt: 0.79e18,
                debtToCover: 0,
                totalBorrowerDebtValue: 1e18,
                totalBorrowerDebtAssets: 1e18,
                totalBorrowerCollateralValue: 100e18,
                totalBorrowerCollateralAssets: 100e18,
                liquidationFee: 0.1e18
            }),
            output: Output({
                collateralAssetsToLiquidate: 0,
                debtAssetsToRepay: 0,
                ltvAfterLiquidation: 0.01e18
            })
        });

        data[i++] = CELAData({ // #3
            input: Input({
                lt: 0.0099e18,
                debtToCover: 1,
                totalBorrowerDebtValue: 1e18,
                totalBorrowerDebtAssets: 1e18,
                totalBorrowerCollateralValue: 100e18,
                totalBorrowerCollateralAssets: 100e18,
                liquidationFee: 0.1e18
            }),
            output: Output({
                collateralAssetsToLiquidate: 1,
                debtAssetsToRepay: 1,
                ltvAfterLiquidation: 0.009999999999999999e18 // (1e18 - 1) / (100e18 - 1)
            })
        });

        data[i++] = CELAData({ // #4
            input: Input({
                lt: 0.01e18,
                debtToCover: 100,
                totalBorrowerDebtValue: 1e18,
                totalBorrowerDebtAssets: 1e18,
                totalBorrowerCollateralValue: 100e18,
                totalBorrowerCollateralAssets: 100e18,
                liquidationFee: 0.01e18 // 1%
            }),
            output: Output({
                collateralAssetsToLiquidate: 101, // 100 debt to cover produces 1 fee
                debtAssetsToRepay: 100,
                ltvAfterLiquidation: 9999999999999999
            })
        });

        data[i++] = CELAData({ // #5
            input: Input({
                lt: 0.80e18,
                debtToCover: 0.5e18, // the value is 40e18 + fee => 44e18 in value
                totalBorrowerDebtValue: 80e18,
                totalBorrowerDebtAssets: 1e18,
                totalBorrowerCollateralValue: 100e18,
                totalBorrowerCollateralAssets: 10e18,
                liquidationFee: 0.10e18
            }),
            output: Output({
                collateralAssetsToLiquidate: 4230769230769230767,
                debtAssetsToRepay: 480769230769230769,
                ltvAfterLiquidation: 720000000000000000 // this is minimal acceptable LTV
            })
        });

        // this is just before full liquidation because of "dust"
        data[i++] = CELAData({ // #6
            input: Input({
                lt: 0.001e18,
                debtToCover: 0.90e18, // the value is 72e18 + fee => 79.2e18 in value
                totalBorrowerDebtValue: 80e18,
                totalBorrowerDebtAssets: 1e18,
                totalBorrowerCollateralValue: 9_000e18,
                totalBorrowerCollateralAssets: 10e18,
                liquidationFee: 0.1e18
            }),
            output: Output({
                collateralAssetsToLiquidate: 87964862992139996, // 79.2e18 / 900 => 0.88,
                debtAssetsToRepay: 0.899640644237795417e18,
                // (80e18 - 72e18) / (9_000e18 - 72e18 - 72e18 * 0.1) = 0.000896780557797507
                ltvAfterLiquidation: 0.000900000000000000e18
            })
        });

        // this will do full liquidation because of dust
        // input values are made up and looks like we have huge collateral
        data[i++] = CELAData({ // #7
            input: Input({
                lt: 0.0088e18,
                debtToCover: 0.91e18, // the value is 72.8e18, but this is too much anyway, it will be lowered by math
                totalBorrowerDebtValue: 80e18,
                totalBorrowerDebtAssets: 1e18, // 1debt token == 80 in value
                totalBorrowerCollateralValue: 9_000e18,
                totalBorrowerCollateralAssets: 10e18, // 1token == 900 in value
                liquidationFee: 0.01e18
            }),
            output: Output({
                collateralAssetsToLiquidate: 9864687385108739,
                debtAssetsToRepay: 109878943646013188,
                ltvAfterLiquidation: 7920000000000000
            })
        });

        // this will do full liquidation because of dust
        // input values are made up and looks like we have huge collateral
        data[i++] = CELAData({ // #8
            input: Input({
                lt: 0.08e18,
                debtToCover: 0.91e18, // the value is 72.8e18, but this is over "dust" margin, so it will be full
                totalBorrowerDebtValue: 80e18,
                totalBorrowerDebtAssets: 1e18, // 1debt token == 80 in value
                totalBorrowerCollateralValue: 90e18,
                totalBorrowerCollateralAssets: 10e18, // 1token == 9 in value
                liquidationFee: 0.01e18
            }),
            output: Output({
                collateralAssetsToLiquidate: uint256(80e18 + 80e18 * 0.01e18 / 1e18) / 9,
                debtAssetsToRepay: 1e18,
                ltvAfterLiquidation: 0
            })
        });

        // if we expect ltv to be 0, we need full liquidation
        data[i++] = CELAData({ // #9
            input: Input({
                lt: 0.08e18,
                debtToCover: 160e18,
                totalBorrowerDebtValue: 80e18,
                totalBorrowerDebtAssets: 160e18,
                totalBorrowerCollateralValue: 100e18,
                totalBorrowerCollateralAssets: 300e18,
                liquidationFee: 0.05e18
            }),
            output: Output({
                collateralAssetsToLiquidate: (80e18 + 80e18 * 0.05e18 / 1e18) * 3, // 252...
                debtAssetsToRepay: 160e18,
                ltvAfterLiquidation: 0
            })
        });

        data[i++] = CELAData({ // #10
            input: Input({
                lt: 0.08e18,
                debtToCover: 10e18,
                totalBorrowerDebtValue: 180e18,
                totalBorrowerDebtAssets: 180e18,
                totalBorrowerCollateralValue: 100e18,
                totalBorrowerCollateralAssets: 100e18,
                liquidationFee: 0.1e18
            }),
            output: Output({
                collateralAssetsToLiquidate: (10e18 + 10e18 * 0.1e18 / 1e18),
                debtAssetsToRepay: 10e18,
                ltvAfterLiquidation: 1_9101_12359550561797
            })
        });

        // we have bad debt and we will cover everything
        data[i++] = CELAData({ // #11
            input: Input({
                lt: 0.99e18,
                debtToCover: 100e18,
                totalBorrowerDebtValue: 12e18,
                totalBorrowerDebtAssets: 12e18,
                totalBorrowerCollateralValue: 10e18,
                totalBorrowerCollateralAssets: 10e18,
                liquidationFee: 0.1e18
            }),
            output: Output({
                collateralAssetsToLiquidate: 10e18,
                debtAssetsToRepay: 12e18,
                ltvAfterLiquidation: 0
            })
        });

        // we have bad debt and we will cover everything #2
        data[i++] = CELAData({ // #12
            input: Input({
                lt: 0.99e18,
                debtToCover: 1000000e18,
                totalBorrowerDebtValue: 12e18,
                totalBorrowerDebtAssets: 18e18,
                totalBorrowerCollateralValue: 10e18,
                totalBorrowerCollateralAssets: 30e18,
                liquidationFee: 0.1e18
            }),
            output: Output({
                collateralAssetsToLiquidate: 30e18,
                debtAssetsToRepay: 18e18,
                ltvAfterLiquidation: 0
            })
        });
    }
}
