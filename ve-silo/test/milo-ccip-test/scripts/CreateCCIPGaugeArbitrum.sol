// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {VmLib} from "silo-foundry-utils/lib/VmLib.sol";
import {Script} from "forge-std/Script.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {VeSiloDeployments, VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";
import {IVeSilo} from "ve-silo/contracts/voting-escrow/interfaces/IVeSilo.sol";
import {CCIPGaugeFactoryArbitrum} from "ve-silo/contracts/gauges/ccip/arbitrum/CCIPGaugeFactoryArbitrum.sol";

/**
FOUNDRY_PROFILE=ve-silo-test CHILD_CHAIN_GAUGE=0x6d228Fa4daD2163056A48Fc2186d716f5c65E89A \
    forge script ve-silo/test/milo-ccip-test/scripts/CreateCCIPGaugeArbitrum.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract CreateCCIPGaugeArbitrum is Script {
    function run() external returns (address gauge) {
        AddrLib.init();
        VmLib.vm().label(AddrLib._ADDRESS_COLLECTION, "AddressesCollection");

        uint256 proposerPrivateKey = uint256(vm.envBytes32("PROPOSER_PRIVATE_KEY"));

        string memory chainAlias = ChainsLib.chainAlias();

        address ccipGaugeFactoryAddr = VeSiloDeployments.get(
            VeSiloContracts.CCIP_GAUGE_FACTORY_ARBITRUM,
            chainAlias
        );

        address recipient = vm.envAddress("CHILD_CHAIN_GAUGE"); // the gauge created on Optimism
        // https://docs.chain.link/ccip/directory/mainnet/chain/ethereum-mainnet-arbitrum-1
        uint64 destinationChain = 3734403246176062136; // Optimism
        uint256 relativeWeightCap = 1e18;

        vm.startBroadcast(proposerPrivateKey);

        gauge = CCIPGaugeFactoryArbitrum(ccipGaugeFactoryAddr).create(recipient, relativeWeightCap, destinationChain);

        vm.stopBroadcast();
    }
}
