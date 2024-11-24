// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";

import {ISiloChildChainGauge} from "ve-silo/contracts/gauges/interfaces/ISiloChildChainGauge.sol";

import {console} from "forge-std/console.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    GAUGE=0x6d504D8cd3d742674F900a9272564f24B57A10BC \
    USER=0x6d228Fa4daD2163056A48Fc2186d716f5c65E89A \
    forge script ve-silo/test/milo-ccip-test/scripts/GetChildChainGaugeUser.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8546
 */
contract GetChildChainGaugeUser is Script {
    function run() external returns (
        uint256 integrateFraction,
        uint256 integrateCheckpoint,
        uint256 claimableTokens,
        uint256 workingSupply,
        uint256 workingBalance,
        address share_token
    ) {
        ISiloChildChainGauge gauge = ISiloChildChainGauge(vm.envAddress("GAUGE"));
        address user = vm.envAddress("USER");

        integrateFraction = gauge.integrate_fraction(user);
        integrateCheckpoint = gauge.integrate_checkpoint_of(user);
        claimableTokens = gauge.claimable_tokens(user);
        workingSupply = gauge.working_supply();
        workingBalance = gauge.working_balances(user);
        share_token = gauge.share_token();

        int128 period = gauge.period();

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        gauge.user_checkpoint(user);

        vm.stopBroadcast();

        console.log("period", uint256(int256(period)));
        console.log("period_timestamp", gauge.period_timestamp(period));
        console.log("integrate_inv_supply", gauge.integrate_inv_supply(period));
    }
}
