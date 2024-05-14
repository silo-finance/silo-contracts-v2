// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {CCIPGaugeFactory} from "../CCIPGaugeFactory.sol";

contract CCIPGaugeFactoryArbitrum is CCIPGaugeFactory {
    constructor(address _beacon, address _checkpointer) CCIPGaugeFactory(_beacon, _checkpointer) {}
}
