// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {BaseGaugeFactory} from "ve-silo/contracts/gauges/BaseGaugeFactory.sol";

contract BaseGaugeFactoryMock is BaseGaugeFactory {
    constructor(address _impl) BaseGaugeFactory(_impl) {}

    function create() external returns (address gauge) {
        gauge = _create();
    }
}
