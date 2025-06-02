// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PendleMarketGasWaster is ERC20 {
    uint256[] public counter;

    constructor() ERC20("PendleMarketGasWaster", "PendleMarketGasWaster") {}

    function redeemRewards(address user) external returns (address[] memory rewardTokens, uint256[] memory rewards) {
        uint256 i = 0;

        while (true) {
            counter.push(i);
            i++;
        }
    }

    function getRewardTokens() external view returns (address[] memory) {
        return new address[](0);
    }
}
