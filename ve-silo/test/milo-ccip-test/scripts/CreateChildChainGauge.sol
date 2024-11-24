// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {VmLib} from "silo-foundry-utils/lib/VmLib.sol";
import {Script} from "forge-std/Script.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {VeSiloDeployments, VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";
import {IVeSilo} from "ve-silo/contracts/voting-escrow/interfaces/IVeSilo.sol";
import {ChildChainGaugeFactory} from "ve-silo/contracts/gauges/l2-common/ChildChainGaugeFactory.sol";

/**
FOUNDRY_PROFILE=ve-silo-test SHARE_TOKEN=0x8941e6232a91283b0eBE51284F54026BB8Fc3bfa \
    forge script ve-silo/test/milo-ccip-test/scripts/CreateChildChainGauge.sol \
    --ffi --broadcast --evm-version shanghai --rpc-url http://127.0.0.1:8546
 */
contract CreateChildChainGauge is Script {
    function run() external returns (address gauge) {
        AddrLib.init();
        VmLib.vm().label(AddrLib._ADDRESS_COLLECTION, "AddressesCollection");

        uint256 devPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        string memory chainAlias = ChainsLib.chainAlias();

        address gaugeFactoryAddr = VeSiloDeployments.get(
            VeSiloContracts.CHILD_CHAIN_GAUGE_FACTORY,
            chainAlias
        );

        address shareToken = vm.envAddress("SHARE_TOKEN");

        vm.startBroadcast(devPrivateKey);

        gauge = ChildChainGaugeFactory(gaugeFactoryAddr).create(shareToken);

        vm.stopBroadcast();
    }
}
