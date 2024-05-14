// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IMainnetBalancerMinter} from "ve-silo/contracts/silo-tokens-minter/interfaces/IMainnetBalancerMinter.sol";
import {CCIPGauge} from "ve-silo/contracts/gauges/ccip/CCIPGauge.sol";

contract CCIPGaugeWithMocks is CCIPGauge {
    constructor(
        IMainnetBalancerMinter _minter,
        address _router,
        address _link
    ) CCIPGauge(
        _minter,
        _router,
        _link
    ) {}
}
