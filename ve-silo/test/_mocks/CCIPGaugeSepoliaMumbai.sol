// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IMainnetBalancerMinter} from "ve-silo/contracts/silo-tokens-minter/interfaces/IMainnetBalancerMinter.sol";
import {CCIPGauge} from "ve-silo/contracts/gauges/ccip/CCIPGauge.sol";

contract CCIPGaugeSepoliaMumbai is CCIPGauge {
    address internal constant _ROUTER = 0xD0daae2231E9CB96b94C8512223533293C3693Bf;
    address internal constant _LINK = 0x779877A7B0D9E8603169DdbD7836e478b4624789;

    constructor(IMainnetBalancerMinter _minter) CCIPGauge(_minter, _ROUTER, _LINK) {}
}
