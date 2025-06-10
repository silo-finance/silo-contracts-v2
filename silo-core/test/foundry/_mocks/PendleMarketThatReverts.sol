// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PendleMarketThatReverts is ERC20 {
    constructor() ERC20("PendleMarketThatReverts", "PendleMarketThatReverts") {}

    function redeemRewards(address user) external returns (address[] memory rewardTokens, uint256[] memory rewards) {
        revert("PendleMarketThatReverts");
    }

    function getRewardTokens() external view returns (address[] memory) {
        return new address[](0);
    }
}
