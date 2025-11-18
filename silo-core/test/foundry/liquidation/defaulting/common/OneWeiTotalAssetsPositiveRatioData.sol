// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

struct SplitInputData {
    uint8 id;
    uint256 assetsToLiquidate;
    uint256 expectedKeeperShares;
    uint256 expectedLendersShares;
    uint256 totalAssets;
    uint256 totalShares;
}

contract OneWeiTotalAssetsPositiveRatioData {
    SplitInputData[] public data;

    constructor() {
        uint256 oneWeiAsset = 1;

        add(
            SplitInputData({
                id: 1,
                assetsToLiquidate: oneWeiAsset,
                expectedKeeperShares: 200,
                expectedLendersShares: 11000 - 200,
                totalAssets: oneWeiAsset,
                totalShares: 11000
            })
        );

        add(
            SplitInputData({
                id: 2,
                assetsToLiquidate: oneWeiAsset,
                expectedKeeperShares: 20,
                expectedLendersShares: 1100 - 20,
                totalAssets: oneWeiAsset,
                totalShares: 1100
            })
        );

        add(
            SplitInputData({
                id: 3,
                assetsToLiquidate: oneWeiAsset,
                expectedKeeperShares: 2,
                expectedLendersShares: 108,
                totalAssets: oneWeiAsset,
                totalShares: 110
            })
        );

        add(
            SplitInputData({
                id: 4,
                assetsToLiquidate: oneWeiAsset,
                expectedKeeperShares: 0,
                expectedLendersShares: 11,
                totalAssets: oneWeiAsset,
                totalShares: 11
            })
        );

        add(
            SplitInputData({
                id: 5,
                assetsToLiquidate: oneWeiAsset,
                expectedKeeperShares: 0,
                expectedLendersShares: 1,
                totalAssets: oneWeiAsset,
                totalShares: 1
            })
        );

        add(
            SplitInputData({
                id: 6,
                assetsToLiquidate: oneWeiAsset,
                expectedKeeperShares: 0,
                expectedLendersShares: 2,
                totalAssets: oneWeiAsset,
                totalShares: 2
            })
        );

        add(
            SplitInputData({
                id: 7,
                assetsToLiquidate: oneWeiAsset,
                expectedKeeperShares: 1,
                expectedLendersShares: 54,
                totalAssets: oneWeiAsset,
                totalShares: 55
            })
        );

        add(
            SplitInputData({
                id: 8,
                assetsToLiquidate: oneWeiAsset,
                expectedKeeperShares: 1,
                expectedLendersShares: 86,
                totalAssets: oneWeiAsset,
                totalShares: 87
            })
        );

        add(
            SplitInputData({
                id: 9,
                assetsToLiquidate: oneWeiAsset,
                expectedKeeperShares: 1,
                expectedLendersShares: 108,
                totalAssets: oneWeiAsset,
                totalShares: 109
            })
        );
    }

    function add(SplitInputData memory _data) public {
        require(_data.totalAssets <= _data.totalShares, "totalAssets must be less than totalShares (positive ratio)");

        data.push(_data);
    }

    function getData() external view returns (SplitInputData[] memory) {
        return data;
    }
}
