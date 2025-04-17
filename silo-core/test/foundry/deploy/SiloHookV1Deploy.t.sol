// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Initializable} from "openzeppelin5/proxy/utils/Initializable.sol";

import {SiloHookV1Deploy} from "silo-core/deploy/SiloHookV1Deploy.s.sol";
import {IGaugeHookReceiver} from "silo-core/contracts/interfaces/IGaugeHookReceiver.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

// FOUNDRY_PROFILE=core_test forge test -vv --ffi --mc SiloHookV1DeployTest
contract SiloHookV1DeployTest is Test {
    // fFOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_siloHookV1Deploy_run
    function test_siloHookV1Deploy_run() public {
        SiloHookV1Deploy deploy = new SiloHookV1Deploy();
        deploy.disableDeploymentsSync();

        IGaugeHookReceiver hookReceiver = deploy.run();
        assertTrue(address(hookReceiver) != address(0), "expect deployed address");

        bytes memory initializationData = abi.encode(makeAddr("owner"));

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        hookReceiver.initialize(ISiloConfig(makeAddr("SiloConfig")), initializationData);
    }
}
