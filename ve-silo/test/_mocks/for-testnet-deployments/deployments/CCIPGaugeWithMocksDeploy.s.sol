// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {CommonDeploy, VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";
import {CCIPGaugeWithMocks} from "ve-silo/test/_mocks/for-testnet-deployments/gauges/CCIPGaugeWithMocks.sol";
import {IMainnetBalancerMinter} from "ve-silo/contracts/silo-tokens-minter/interfaces/IMainnetBalancerMinter.sol";
import {VeSiloMocksContracts} from "./VeSiloMocksContracts.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/_mocks/for-testnet-deployments/deployments/CCIPGaugeWithMocksDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract CCIPGaugeWithMocksDeploy is CommonDeploy {
    function run() public returns (CCIPGaugeWithMocks gauge) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address link = getAddress(AddrKey.LINK);
        address router = getAddress(AddrKey.CHAINLINK_CCIP_ROUTER);
        IMainnetBalancerMinter minter = IMainnetBalancerMinter(getAddress(VeSiloContracts.MAINNET_BALANCER_MINTER));

        vm.startBroadcast(deployerPrivateKey);

        gauge = new CCIPGaugeWithMocks(minter, router, link);

        vm.stopBroadcast();

        _registerDeployment(address(gauge), VeSiloMocksContracts.CCIP_GAUGE_WITH_MOCKS);
    }
}
