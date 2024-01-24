// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {IMainnetBalancerMinter} from "ve-silo/contracts/silo-tokens-minter/interfaces/IMainnetBalancerMinter.sol";
import {CCIPGauge} from "ve-silo/contracts/gauges/ccip/CCIPGauge.sol";

contract CCIPGaugeWithMocks is CCIPGauge {
    uint64 internal constant _DESTINATION_CHAIN = 1; // Any chain id

    constructor(
        IMainnetBalancerMinter _minter,
        address _router,
        address _link
    ) CCIPGauge(
        _minter,
        _router,
        _link,
        _DESTINATION_CHAIN
    ) {}
}
