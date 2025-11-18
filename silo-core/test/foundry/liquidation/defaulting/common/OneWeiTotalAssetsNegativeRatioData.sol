// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {SplitInputData} from "./OneWeiTotalAssetsPositiveRatioData.sol";

contract OneWeiTotalAssetsNegativeRatioData {
    SplitInputData[] public data;

    constructor() {
        uint256 oneWeiAsset = 1;

        add(
            SplitInputData({
                id: 1,
                assetsToLiquidate: oneWeiAsset,
                expectedKeeperShares: 0,
                expectedLendersShares: 10,
                totalAssets: 100,
                totalShares: 10
            })
        );

        add(
            SplitInputData({
                id: 2,
                assetsToLiquidate: oneWeiAsset,
                expectedKeeperShares: 0,
                expectedLendersShares: 1,
                totalAssets: 100,
                totalShares: 10
            })
        );
    }

    function add(SplitInputData memory _data) public {
        require(
            _data.totalAssets >= _data.totalShares,
            "totalAssets must be greater than or equal to totalShares (negative ratio)"
        );
        data.push(_data);
    }

    function getData() external view returns (SplitInputData[] memory) {
        return data;
    }
}
