// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IChildChainGauge} from "balancer-labs/v2-interfaces/liquidity-mining/IChildChainGauge.sol";

interface IChildChainGaugeRegistry {
    function addGauge(IChildChainGauge gauge) external;
    function removeGauge(IChildChainGauge gauge) external;
    function totalGauges() external view returns (uint256);
    function getGauges(uint256 startIndex, uint256 endIndex) external view returns (IChildChainGauge[] memory);
}
