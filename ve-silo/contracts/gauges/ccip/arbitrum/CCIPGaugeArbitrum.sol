// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IMainnetBalancerMinter} from "ve-silo/contracts/silo-tokens-minter/interfaces/IMainnetBalancerMinter.sol";
import {CCIPGauge} from "ve-silo/contracts/gauges/ccip/CCIPGauge.sol";

contract CCIPGaugeArbitrum is CCIPGauge {
    address internal constant _ROUTER = 0x141fa059441E0ca23ce184B6A78bafD2A517DdE8;
    address internal constant _LINK = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;

    constructor(IMainnetBalancerMinter _minter) CCIPGauge(_minter, _ROUTER, _LINK) {}
}
