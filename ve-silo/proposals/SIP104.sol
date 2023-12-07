// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {Script} from "forge-std/Script.sol";

import {Proposal} from "./_engine/Proposal.sol";

/**
FOUNDRY_PROFILE=ve-silo \
    forge script ve-silo/proposals/SIP104.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract SIP104 is Script, Proposal {
    function run() public {
        gaugeAdder.addGaugeType("Ethereum");
        gaugeAdder.addGauge(address(1), "Ethereum");

        executeProposal("Gauge configuration");
    }
}
