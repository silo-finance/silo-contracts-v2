// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

library DistributionTypes {
    struct IncentivesProgramCreationInput {
        string name;
        address rewardToken;
        uint256 emissionPerSecond;
        uint40 distributionEnd;
    }

    struct AssetConfigInput {
        uint256 emissionPerSecond;
        uint256 totalStaked;
        address underlyingAsset;
    }

    struct UserStakeInput {
        address underlyingAsset;
        uint256 stakedByUser;
        uint256 totalStaked;
    }
}
