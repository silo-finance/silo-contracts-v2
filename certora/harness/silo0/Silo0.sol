// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {SiloHarness} from "../SiloHarness.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";

contract Silo0 is SiloHarness {
    constructor(ISiloFactory _siloFactory) SiloHarness(_siloFactory) {}
}
