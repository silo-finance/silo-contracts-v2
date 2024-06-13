// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {VmLib} from "silo-foundry-utils/lib/VmLib.sol";
import {Script} from "forge-std/Script.sol";
import {Ownable2Step} from "openzeppelin5/access/Ownable2Step.sol";

import {VeSiloDeployments, VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";
import {VeSiloMocksContracts} from "ve-silo/test/_mocks/for-testnet-deployments/deployments/VeSiloMocksContracts.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/_mocks/for-testnet-deployments/scripts/TransferSiloMockOwnership.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract TransferMockSiloTokenOwnership is Script {
    function run() external {
        AddrLib.init();
        VmLib.vm().label(AddrLib._ADDRESS_COLLECTION, "AddressesCollection");

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        string memory chainAlias = ChainsLib.chainAlias();

        address mockToken = VeSiloDeployments.get(VeSiloMocksContracts.SILO_TOKEN_LIKE, chainAlias);
        address balancerTokenAdmin = VeSiloDeployments.get(VeSiloContracts.BALANCER_TOKEN_ADMIN, chainAlias);

        vm.startBroadcast(deployerPrivateKey);

        Ownable2Step(mockToken).transferOwnership(balancerTokenAdmin);

        vm.stopBroadcast();
    }
}
