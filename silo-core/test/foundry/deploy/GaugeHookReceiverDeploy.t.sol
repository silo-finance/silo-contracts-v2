// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {Initializable} from "openzeppelin5/proxy/utils/Initializable.sol";

import {GaugeHookReceiverDeploy} from "silo-core/deploy/GaugeHookReceiverDeploy.s.sol";

import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";
import {IGaugeHookReceiver} from "silo-core/contracts/interfaces/IGaugeHookReceiver.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

// FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc GaugeHookReceiverTest
contract GaugeHookReceiverDeployTest is Test {
    // fFOUNDRY_PROFILE=core-test forge test -vv --ffi --mt test_GaugeHookReceiverDeploy_run
    function test_GaugeHookReceiverDeploy_run() public {
        GaugeHookReceiverDeploy deploy = new GaugeHookReceiverDeploy();
        deploy.disableDeploymentsSync();

        IGaugeHookReceiver hookReceiver = deploy.run();
        assertTrue(address(hookReceiver) != address(0), "expect deployed address");

        bytes memory initializationData = abi.encode(makeAddr("owner"));

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        hookReceiver.initialize(ISiloConfig(makeAddr("SiloConfig")), initializationData);
    }
}
