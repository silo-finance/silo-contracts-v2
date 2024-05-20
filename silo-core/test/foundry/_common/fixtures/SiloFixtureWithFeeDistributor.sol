// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";
import {SiloFixture} from "./SiloFixture.sol";

contract SiloFixtureWithFeeDistributor is SiloFixture {
    constructor() {
        // mocking fee distributor address to make 
        AddrLib.setAddress(VeSiloContracts.FEE_DISTRIBUTOR, makeAddr("FeeDistributor"));
    }
}
