// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {CommonDeploy, VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";
import {CCIPGaugeFactoryAnyChain} from "ve-silo/test/_mocks/CCIPGaugeFactoryAnyChain.sol";
import {VeSiloMocksContracts} from "./VeSiloMocksContracts.sol";

/**
FOUNDRY_PROFILE=ve-silo \
    forge script ve-silo/test/_mocks/for-testnet-deployments/deployments/CCIPGaugeFactoryAnyChainDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract CCIPGaugeFactoryAnyChainDeploy is CommonDeploy {
    uint256 public constant RELATIVE_WEIGHT_CAP = 1e18;

    function run() public returns (CCIPGaugeFactoryAnyChain factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address gaugeImplementation = getAddress("CCIP_GAUGE_WITH_MOCKS_CUSTOM_IMPL");
        address adaptor = getAddress(VeSiloContracts.STAKELESS_GAUGE_CHECKPOINTER_ADAPTOR);

        vm.startBroadcast(deployerPrivateKey);

        factory = new CCIPGaugeFactoryAnyChain(adaptor, gaugeImplementation);

        vm.stopBroadcast();

        _registerDeployment(address(factory), VeSiloMocksContracts.CCIP_GAUGE_FACTORY_ANY_CHAIN);
    }
}
