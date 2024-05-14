// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {CommonDeploy, VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";

import {AddrKey} from "common/addresses/AddrKey.sol";
import {CCIPRouterClientLike} from "ve-silo/test/_mocks/for-testnet-deployments/ccip/CCIPRouterClientLike.sol";
import {VeSiloMocksContracts} from "./VeSiloMocksContracts.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/_mocks/for-testnet-deployments/deployments/CCIPRouterClientLikeDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract CCIPRouterClientLikeDeploy is CommonDeploy {
    function run() public returns (CCIPRouterClientLike routerClient) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address link = getAddress(AddrKey.LINK);
        address silo = getAddress(SILO_TOKEN);

        vm.startBroadcast(deployerPrivateKey);

        routerClient = new CCIPRouterClientLike(silo, link);

        vm.stopBroadcast();

        _registerDeployment(address(routerClient), VeSiloMocksContracts.CCIP_ROUTER_CLIENT_LIKE);
    }
}
