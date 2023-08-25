// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";
import {ChildChainGaugeRegistry} from "ve-silo/contracts/gauges/l2-common/ChildChainGaugeRegistry.sol";
import {IChildChainGaugeRegistry} from "ve-silo/contracts/gauges/interfaces/IChildChainGaugeRegistry.sol";
import {IL2BalancerPseudoMinter} from "ve-silo/contracts/gauges/interfaces/IL2BalancerPseudoMinter.sol";

/**
FOUNDRY_PROFILE=ve-silo \
    forge script ve-silo/deploy/ChildChainGaugeRegistryDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract ChildChainGaugeRegistryDeploy is CommonDeploy {
    function run() public returns (IChildChainGaugeRegistry registry) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        address l2BalancerPseudeMinter = getDeployedAddress(VeSiloContracts.L2_BALANCER_PSEUDO_MINTER);

        registry = IChildChainGaugeRegistry(address(
            new ChildChainGaugeRegistry(IL2BalancerPseudoMinter(l2BalancerPseudeMinter)) 
        ));

        _registerDeployment(address(registry), VeSiloContracts.CHILD_CHAIN_GAUGE_REGISTRY);

        vm.stopBroadcast();

        _syncDeployments();
    }
}
