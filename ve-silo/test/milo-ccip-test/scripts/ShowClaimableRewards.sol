// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {VmLib} from "silo-foundry-utils/lib/VmLib.sol";
import {Script} from "forge-std/Script.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {IStakelessGauge} from "ve-silo/contracts/gauges/interfaces/IStakelessGauge.sol";
import {IGaugeController} from "ve-silo/contracts/gauges/interfaces/IGaugeController.sol";

import {VeSiloDeployments, VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    GAUGE=0xe26b060eB0aE73D93875840D0b44CA87884631d7 \
    forge script ve-silo/test/milo-ccip-test/scripts/ShowClaimableRewards.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract ShowClaimableRewards is Script {
    function run() external returns (
        uint256 claimable,
        uint256 pointsTotal,
        uint256 relativeWeightCap,
        int128 nGauges,
        int128 nGaugesTypes
    ) {
        AddrLib.init();
        VmLib.vm().label(AddrLib._ADDRESS_COLLECTION, "AddressesCollection");

        address gauge = VmLib.vm().envAddress("GAUGE");

        address controller = VeSiloDeployments.get(VeSiloContracts.GAUGE_CONTROLLER, ChainsLib.chainAlias());

        IGaugeController(controller).gauge_relative_weight_write(gauge, 1732147200);

        claimable = IStakelessGauge(gauge).unclaimedIncentives();
        relativeWeightCap = IStakelessGauge(gauge).getRelativeWeightCap();

        pointsTotal = IGaugeController(controller).points_total(1732147200);
        nGauges = IGaugeController(controller).n_gauges();
        nGaugesTypes = IGaugeController(controller).n_gauge_types();
    }
}
