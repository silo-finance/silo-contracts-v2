// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Silo} from "./Silo.sol";
import {SiloStorageLib} from "./lib/SiloStorageLib.sol";
import {ISiloFactory} from "./interfaces/ISiloFactory.sol";

contract NoInterestForDebtSilo is Silo {
    constructor(ISiloFactory _factory) Silo(_factory) {
        SiloStorageLib.getSiloStorage().ignoreInterestRateForDebt = true;
    }
}
