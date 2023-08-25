// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {IL2LayerZeroDelegation} from "balancer-labs/v2-interfaces/liquidity-mining/IL2LayerZeroDelegation.sol";

import {VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";
import {ChildChainGaugeCheckpointerDeploy} from "ve-silo/deploy/ChildChainGaugeCheckpointerDeploy.s.sol";

// FOUNDRY_PROFILE=ve-silo forge test --mc ChildChainGaugeCheckpointer --ffi -vvv
contract ChildChainGaugeCheckpointer is IntegrationTest {
    address internal _registry = makeAddr("Child chain gauge registry");

    ChildChainGaugeCheckpointerDeploy internal _deploy;

    function setUp() public {
        _deploy = new ChildChainGaugeCheckpointerDeploy();
        _deploy.disableDeploymentsSync();

        setAddress(VeSiloContracts.CHILD_CHAIN_GAUGE_REGISTRY, _registry);
    }

    function testDeployment() public {
        IL2LayerZeroDelegation checkpointer = _deploy.run();

        assertTrue(address(checkpointer) != address(0), "Deployment failed");
    }
}
