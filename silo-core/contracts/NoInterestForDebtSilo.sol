// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Silo} from "./Silo.sol";
import {SiloStorageLib} from "./lib/SiloStorageLib.sol";
import {ISiloFactory} from "./interfaces/ISiloFactory.sol";
import {ISiloConfig} from "./interfaces/ISiloConfig.sol";

contract NoInterestForDebtSilo is Silo {
    constructor(ISiloFactory _factory) Silo(_factory) {}

    function initialize(ISiloConfig _config) public override {
        super.initialize(_config);
        SiloStorageLib.getSiloStorage().ignoreInterestRateForDebt = true;
    }
}
