// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

/**
FOUNDRY_PROFILE=ve-silo-test SILO_CONFIG=0x \
    forge script ve-silo/test/milo-ccip-test/scripts/SiloDetails.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract SiloDetails is Script {
    function run() external returns (
        address silo0,
        address silo0CollateralToken,
        address silo1,
        address silo1CollateralToken
    ) {
        ISiloConfig siloConfig = ISiloConfig(vm.envAddress("SILO_CONFIG"));

        (silo0, silo1) = siloConfig.getSilos();

        (, silo0CollateralToken,) = siloConfig.getShareTokens(silo0);
        (, silo1CollateralToken,) = siloConfig.getShareTokens(silo1);
    }
}
