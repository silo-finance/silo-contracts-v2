// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IMainnetBalancerMinter} from "ve-silo/contracts/silo-tokens-minter/interfaces/IMainnetBalancerMinter.sol";
import {CCIPGaugeFactory} from "ve-silo/contracts/gauges/ccip/CCIPGaugeFactory.sol";

contract CCIPGaugeFactoryAnyChain is CCIPGaugeFactory {
    constructor(address _beacon, address _checkpointer)
        CCIPGaugeFactory(_beacon, _checkpointer)
    {}
}
