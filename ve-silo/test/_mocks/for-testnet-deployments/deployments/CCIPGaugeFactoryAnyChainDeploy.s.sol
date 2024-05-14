// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IBeacon} from "openzeppelin5/proxy/beacon/IBeacon.sol";

import {CommonDeploy, VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";
import {CCIPGaugeFactoryAnyChain} from "ve-silo/test/_mocks/CCIPGaugeFactoryAnyChain.sol";
import {VeSiloMocksContracts} from "./VeSiloMocksContracts.sol";

import {
    CCIPGaugeArbitrumUpgradeableBeacon
} from "ve-silo/contracts/gauges/ccip/arbitrum/CCIPGaugeArbitrumUpgradeableBeacon.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/_mocks/for-testnet-deployments/deployments/CCIPGaugeFactoryAnyChainDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract CCIPGaugeFactoryAnyChainDeploy is CommonDeploy {
    uint256 public constant RELATIVE_WEIGHT_CAP = 1e18;

    function run() public returns (CCIPGaugeFactoryAnyChain factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address initialOwner = getAddress(VeSiloContracts.TIMELOCK_CONTROLLER);
        address gaugeImplementation = getAddress(VeSiloMocksContracts.CCIP_GAUGE_WITH_MOCKS);
        address adaptor = getAddress(VeSiloContracts.STAKELESS_GAUGE_CHECKPOINTER_ADAPTOR);

        vm.startBroadcast(deployerPrivateKey);

        IBeacon beacon = IBeacon(address(new CCIPGaugeArbitrumUpgradeableBeacon(gaugeImplementation, initialOwner)));

        factory = new CCIPGaugeFactoryAnyChain(address(beacon), adaptor);

        vm.stopBroadcast();

        _registerDeployment(address(factory), VeSiloMocksContracts.CCIP_GAUGE_FACTORY_ANY_CHAIN);
    }
}
