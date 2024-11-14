// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {VmLib} from "silo-foundry-utils/lib/VmLib.sol";
import {Script} from "forge-std/Script.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {VeSiloDeployments, VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/_mocks/for-testnet-deployments/milo-scripts/SendMiloToProposer.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract SendMiloToProposer is Script {
    function run() external returns (uint256 proposerBalance) {
        AddrLib.init();
        VmLib.vm().label(AddrLib._ADDRESS_COLLECTION, "AddressesCollection");

        uint256 proposerPrivateKey = uint256(vm.envBytes32("PROPOSER_PRIVATE_KEY"));
        address proposer = vm.addr(proposerPrivateKey);

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address miloToken = VeSiloDeployments.get(VeSiloContracts.MILO_TOKEN, ChainsLib.chainAlias());

        vm.startBroadcast(deployerPrivateKey);

        IERC20(miloToken).transfer(proposer, 1000_000e18);

        vm.stopBroadcast();

        proposerBalance = IERC20(miloToken).balanceOf(proposer);
    }
}
