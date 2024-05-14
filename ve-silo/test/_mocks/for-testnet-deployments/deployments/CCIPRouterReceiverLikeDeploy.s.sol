// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {CommonDeploy, VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";

import {AddrKey} from "common/addresses/AddrKey.sol";
import {CCIPRouterReceiverLike} from "ve-silo/test/_mocks/for-testnet-deployments/ccip/CCIPRouterReceiverLike.sol";
import {VeSiloMocksContracts} from "./VeSiloMocksContracts.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/_mocks/for-testnet-deployments/deployments/CCIPRouterReceiverLikeDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract CCIPRouterReceiverLikeDeploy is CommonDeploy {
    function run() public returns (CCIPRouterReceiverLike routerReceiver) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        routerReceiver = new CCIPRouterReceiverLike();

        vm.stopBroadcast();

        _registerDeployment(address(routerReceiver), VeSiloMocksContracts.CCIP_ROUTER_RECEIVER_LIKE);
    }
}
