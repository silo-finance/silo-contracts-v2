// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import {ILiquidityGaugeFactory} from "ve-silo/contracts/gauges/interfaces/ILiquidityGaugeFactory.sol";
import {IBalancerMinter} from "./IBalancerMinter.sol";

interface IL2BalancerPseudoMinter is IBalancerMinter {
    function addGaugeFactory(ILiquidityGaugeFactory factory) external;
    function removeGaugeFactory(ILiquidityGaugeFactory factory) external;
    function isValidGaugeFactory(ILiquidityGaugeFactory factory) external view returns (bool);
}
