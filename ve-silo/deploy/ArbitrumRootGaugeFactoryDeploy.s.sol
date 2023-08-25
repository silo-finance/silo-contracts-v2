// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";

import {ArbitrumRootGaugeFactory, IMainnetBalancerMinter, IGatewayRouter}
    from "ve-silo/contracts/gauges/arbitrum/ArbitrumRootGaugeFactory.sol";

/**
FOUNDRY_PROFILE=ve-silo \
    forge script ve-silo/deploy/ArbitrumRootGaugeFactoryDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract ArbitrumRootGaugeFactoryDeploy is CommonDeploy {
    // arbitrum fees
    // these parameters can be updated after deployment if needed
    uint64 public gasLimit = 1000000;
    uint64 public gasPrice = 1990000000;
    uint64 public maxSubmissionCost = 1000000000000000;

    function run() public returns (ArbitrumRootGaugeFactory factory) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        address minter = getDeployedAddress(VeSiloContracts.MAINNET_BALANCER_MINTER);
        address gatewayRouter = getAddress(ARBITRUM_GATEWAY_ROUTER);

        factory = new ArbitrumRootGaugeFactory(
            IMainnetBalancerMinter(minter),
            IGatewayRouter(gatewayRouter),
            gasLimit,
            gasPrice,
            maxSubmissionCost
        );

        vm.stopBroadcast();

        address gaugeImplementation = factory.getGaugeImplementation();

        _registerDeployment(gaugeImplementation, VeSiloContracts.ARBITRUM_ROOT_GAUGE);
        _registerDeployment(address(factory), VeSiloContracts.ARBITRUM_ROOT_GAUGE_FACTORY);

        _syncDeployments();
    }
}
