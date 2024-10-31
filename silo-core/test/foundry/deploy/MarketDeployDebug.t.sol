// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {SiloDeployWithGaugeHookReceiver} from "silo-core/deploy/silo/SiloDeployWithGaugeHookReceiver.s.sol";

// FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc MarketDeployDebugTest
contract MarketDeployDebugTest is IntegrationTest {
    SiloDeployWithGaugeHookReceiver internal _siloDeploy;

    function setUp() external {
        vm.createSelectFork(
            getChainRpcUrl(ARBITRUM_ONE_ALIAS), // change if needed
            269494200
        );

        siloDeploy = new SiloDeployWithGaugeHookReceiver();
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_deployMarket
    function test_deployMarket() public {
        // _siloDeploy.useConfig("GM_WETH_Silo"); // set market config name
        // _siloDeploy.run();
    }
}
