// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.28;

library DistributionTypes {
    struct IncentivesProgramCreationInput {
        string name;
        address rewardToken;
        uint104 emissionPerSecond;
        uint40 distributionEnd;
    }

    struct AssetConfigInput {
        uint104 emissionPerSecond;
        uint256 totalStaked;
        address underlyingAsset;
    }

    struct UserStakeInput {
        address underlyingAsset;
        uint256 stakedByUser;
        uint256 totalStaked;
    }
}
