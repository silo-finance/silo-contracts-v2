// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {IMainnetBalancerMinter} from "ve-silo/contracts/silo-tokens-minter/interfaces/IMainnetBalancerMinter.sol";
import {CCIPGaugeFactory} from "ve-silo/contracts/gauges/ccip/CCIPGaugeFactory.sol";

contract CCIPGaugeFactorySepoliaMumbai is CCIPGaugeFactory {
    constructor(address _checkpointer, address _gaugeImplementation)
        CCIPGaugeFactory(_checkpointer, _gaugeImplementation)
    {}
}
