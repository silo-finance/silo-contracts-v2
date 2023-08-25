// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IL2LayerZeroDelegation} from "balancer-labs/v2-interfaces/liquidity-mining/IL2LayerZeroDelegation.sol";

import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";
import {ChildChainGaugeCheckpointer} from "ve-silo/contracts/gauges/l2-common/ChildChainGaugeCheckpointer.sol";
import {IChildChainGaugeRegistry} from "ve-silo/contracts/gauges/interfaces/IChildChainGaugeRegistry.sol";

/**
FOUNDRY_PROFILE=ve-silo \
    forge script ve-silo/deploy/ChildChainGaugeCheckpointerDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract ChildChainGaugeCheckpointerDeploy is CommonDeploy {
    function run() public returns (IL2LayerZeroDelegation checkpointer) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        IChildChainGaugeRegistry registry =
            IChildChainGaugeRegistry(getDeployedAddress(VeSiloContracts.CHILD_CHAIN_GAUGE_REGISTRY));

        checkpointer = ChildChainGaugeCheckpointer(address(
            new ChildChainGaugeCheckpointer(registry) 
        ));

        _registerDeployment(address(registry), VeSiloContracts.CHILD_CHAIN_GAUGE_CHECKPOINTER);

        vm.stopBroadcast();

        _syncDeployments();
    }
}
