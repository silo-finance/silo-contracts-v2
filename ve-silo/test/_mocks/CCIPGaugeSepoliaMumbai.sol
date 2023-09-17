// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IMainnetBalancerMinter} from "ve-silo/contracts/silo-tokens-minter/interfaces/IMainnetBalancerMinter.sol";
import {CCIPGauge} from "ve-silo/contracts/gauges/ccip/CCIPGauge.sol";

contract CCIPGaugeSepoliaMumbai is CCIPGauge {
    address internal constant _ROUTER = 0xD0daae2231E9CB96b94C8512223533293C3693Bf;
    address internal constant _LINK = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    uint64 internal constant _DESTINATION_CHAIN = 12532609583862916517; // Polygon Mumbai

    constructor(IMainnetBalancerMinter _minter) CCIPGauge(
        _minter,
        _ROUTER,
        _LINK,
        _DESTINATION_CHAIN
    ) {}
}
