// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";
import {SiloFixture} from "./SiloFixture.sol";

// With mocked addresses that we need for the `SiloFactoryDeploy` script
contract SiloFixtureWithVeSilo is SiloFixture {
    constructor() {
        AddrLib.init();

        address timelock = AddrLib.getAddress(VeSiloContracts.TIMELOCK_CONTROLLER);

        if (timelock == address(0)) {
            AddrLib.setAddress(VeSiloContracts.TIMELOCK_CONTROLLER, makeAddr("Timelock"));
        }
        
        address feeDistributor = AddrLib.getAddress(VeSiloContracts.FEE_DISTRIBUTOR);

        if (feeDistributor == address(0)) {
            AddrLib.setAddress(VeSiloContracts.FEE_DISTRIBUTOR, makeAddr("FeeDistributor"));
        }
    }
}
