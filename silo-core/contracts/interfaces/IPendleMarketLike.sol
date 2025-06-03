// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IPendleMarketLike {
    function redeemRewards(address user) external returns (uint256[] memory);
    function getRewardTokens() external view returns (address[] memory);
}
