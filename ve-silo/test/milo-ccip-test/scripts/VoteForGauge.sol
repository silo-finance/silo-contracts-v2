// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {VmLib} from "silo-foundry-utils/lib/VmLib.sol";
import {Script} from "forge-std/Script.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {IGaugeController} from "ve-silo/contracts/gauges/interfaces/IGaugeController.sol";

import {VeSiloDeployments, VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    GAUGE=0xe26b060eB0aE73D93875840D0b44CA87884631d7 \
    forge script ve-silo/test/milo-ccip-test/scripts/VoteForGauge.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract VoteForGauge is Script {
    function run() external {
        AddrLib.init();
        VmLib.vm().label(AddrLib._ADDRESS_COLLECTION, "AddressesCollection");

        address gauge = VmLib.vm().envAddress("GAUGE");

        uint256 proposerPrivateKey = uint256(vm.envBytes32("PROPOSER_PRIVATE_KEY"));

        string memory chainAlias = ChainsLib.chainAlias();

        address controller = VeSiloDeployments.get(VeSiloContracts.GAUGE_CONTROLLER, chainAlias);

        vm.startBroadcast(proposerPrivateKey);

        IGaugeController(controller).vote_for_gauge_weights(gauge, 10000);

        vm.stopBroadcast();
    }
}
