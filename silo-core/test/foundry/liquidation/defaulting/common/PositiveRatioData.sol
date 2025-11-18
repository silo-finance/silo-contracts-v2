// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {SplitInputData} from "./OneWeiTotalAssetsPositiveRatioData.sol";

contract PositiveRatioData {
    SplitInputData[] public data;

    constructor() {
        // add(
        //     SplitInputData({ // fail
        //         id: 1,
        //         assetsToLiquidate: 1,
        //         expectedKeeperShares: 1,
        //         expectedLendersShares: 9,
        //         totalAssets: 10,
        //         totalShares: 100
        //     })
        // );

        // add(
        //     SplitInputData({ // fail
        //         id: 2,
        //         assetsToLiquidate: 1,
        //         expectedKeeperShares: 1,
        //         expectedLendersShares: 50,
        //         totalAssets: 10,
        //         totalShares: 500
        //     })
        // );

        add(
            SplitInputData({ // fail
                id: 3,
                assetsToLiquidate: 1,
                expectedKeeperShares: 2,
                expectedLendersShares: 98,
                totalAssets: 10,
                totalShares: 1000
            })
        );

        // so anything below offset ratio of offset:1 fails?
    }

    function add(SplitInputData memory _data) public {
        require(_data.totalAssets <= _data.totalShares, "totalAssets must be less than totalShares (positive ratio)");

        data.push(_data);
    }

    function getData() external view returns (SplitInputData[] memory) {
        return data;
    }
}
