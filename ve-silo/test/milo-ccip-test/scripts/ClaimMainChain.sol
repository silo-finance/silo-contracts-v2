// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {VmLib} from "silo-foundry-utils/lib/VmLib.sol";
import {Script} from "forge-std/Script.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {Constants} from "proposals/sip/_common/Constants.sol";

import {IStakelessGauge} from "ve-silo/contracts/gauges/interfaces/IStakelessGauge.sol";
import {IGaugeController} from "ve-silo/contracts/gauges/interfaces/IGaugeController.sol";
import {IMainnetBalancerMinter} from "ve-silo/contracts/silo-tokens-minter/interfaces/IMainnetBalancerMinter.sol";

import {ICCIPGauge} from "ve-silo/contracts/gauges/interfaces/ICCIPGauge.sol";
import {ICCIPGaugeCheckpointer} from "ve-silo/contracts/gauges/stakeless-gauge/CCIPGaugeCheckpointer.sol";

import {VeSiloDeployments, VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    GAUGE=0xe26b060eB0aE73D93875840D0b44CA87884631d7 \
    forge script ve-silo/test/milo-ccip-test/scripts/ClaimMainChain.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545 -vvvv
 */
contract ClaimMainChain is Script {
    function run() external returns (uint256 claimed) {
        AddrLib.init();
        VmLib.vm().label(AddrLib._ADDRESS_COLLECTION, "AddressesCollection");

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        address gauge = VmLib.vm().envAddress("GAUGE");

        address checkpointer = VeSiloDeployments.get(VeSiloContracts.CCIP_GAUGE_CHECKPOINTER, ChainsLib.chainAlias());
        address minter = VeSiloDeployments.get(VeSiloContracts.MAINNET_BALANCER_MINTER, ChainsLib.chainAlias());

        uint256 mintedBefore = IMainnetBalancerMinter(minter).minted(gauge, gauge);

        vm.startBroadcast(deployerPrivateKey);

        ICCIPGaugeCheckpointer(checkpointer).checkpointSingleGauge{value: 0.001 ether}(
            Constants._GAUGE_TYPE_CHILD,
            ICCIPGauge(gauge),
            ICCIPGauge.PayFeesIn.Native
        );

        vm.stopBroadcast();

        uint256 mintedAfter = IMainnetBalancerMinter(minter).minted(gauge, gauge);

        claimed = mintedAfter - mintedBefore;
    }
}
