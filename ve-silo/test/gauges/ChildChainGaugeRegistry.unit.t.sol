// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {IChildChainGauge} from "balancer-labs/v2-interfaces/liquidity-mining/IChildChainGauge.sol";

import {VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";
import {IChildChainGaugeRegistry} from "ve-silo/contracts/gauges/interfaces/IChildChainGaugeRegistry.sol";
import {ChildChainGaugeRegistryDeploy} from "ve-silo/deploy/ChildChainGaugeRegistryDeploy.s.sol";

// FOUNDRY_PROFILE=ve-silo forge test --mc ChildChainGaugeRegistry --ffi -vvv
contract ChildChainGaugeRegistry is IntegrationTest {
    address internal _l2BalancerMinter = makeAddr("L2Balancer minter");

    IChildChainGaugeRegistry internal _registry;

    function setUp() public {
        ChildChainGaugeRegistryDeploy deploy = new ChildChainGaugeRegistryDeploy();
        deploy.disableDeploymentsSync();

        setAddress(VeSiloContracts.L2_BALANCER_PSEUDO_MINTER, _l2BalancerMinter);

        _registry = deploy.run();
    }

    function testPermissions() public {
        vm.expectRevert("Ownable: caller is not the owner");
        _registry.addGauge(IChildChainGauge(address(1)));

        vm.expectRevert("Ownable: caller is not the owner");
        _registry.removeGauge(IChildChainGauge(address(1)));
    }
}
