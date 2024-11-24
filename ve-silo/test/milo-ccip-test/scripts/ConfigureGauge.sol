// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {Script} from "forge-std/Script.sol";

import {IGaugeHookReceiver} from "silo-core/contracts/interfaces/IGaugeHookReceiver.sol";
import {IGaugeLike as IGauge} from "silo-core/contracts/interfaces/IGaugeLike.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    GAUGE=0xAE49FC63f11Ef6800937C4df81d8fb566e99ea08 \
    GAUGE_HOOK=0xDA04B1Dac50bF95c5ddcc0DA4659092D653b3047 \
    SHARE_TOKEN=0x2ae20A761Ae36d4d895EE7Ef43ABC7B739Aff51f \
    forge script ve-silo/test/milo-ccip-test/scripts/ConfigureGauge.sol \
    --ffi --broadcast --evm-version shanghai --rpc-url http://127.0.0.1:8546
 */
contract ConfigureGauge is Script {
    function run() external {
        AddrLib.init();

        uint256 devPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address gauge = vm.envAddress("GAUGE");
        address gaugeHook = vm.envAddress("GAUGE_HOOK");
        address shareToken = vm.envAddress("SHARE_TOKEN");

        vm.startBroadcast(devPrivateKey);

        IGaugeHookReceiver(gaugeHook).setGauge(IGauge(gauge), IShareToken(shareToken));

        vm.stopBroadcast();
    }
}
