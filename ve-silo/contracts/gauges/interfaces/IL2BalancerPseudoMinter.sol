// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.0 <0.9.0;

import {ILiquidityGaugeFactory} from "balancer-labs/v2-interfaces/liquidity-mining/ILiquidityGaugeFactory.sol";

interface IL2BalancerPseudoMinter {
    function isValidGaugeFactory(ILiquidityGaugeFactory _factory) external view returns (bool);
}
