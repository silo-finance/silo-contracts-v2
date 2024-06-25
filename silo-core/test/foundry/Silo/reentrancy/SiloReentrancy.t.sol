// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {Registries} from "./registries/Registries.sol";
import {IMethodsRegistry} from "./interfaces/IMethodsRegistry.sol";
import {MaliciousToken} from "./MaliciousToken.sol";
import {TestStateLib} from "./TestState.sol";
import {IMethodReentrancyTest} from "./interfaces/IMethodReentrancyTest.sol"; 
import {SiloFixtureWithVeSilo as SiloFixture} from "../../_common/fixtures/SiloFixtureWithVeSilo.sol";
import {SiloConfigOverride} from "../../_common/fixtures/SiloFixture.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

// FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc SiloReentrancyTest
contract SiloReentrancyTest is Test {
    // FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_reentrancy
    function test_reentrancy() public {
        _deploySiloWithOverrides();
        Registries registries = new Registries();
        IMethodsRegistry[] memory methodRegistries = registries.list();

        emit log_string("\n\nRunning reentrancy test");

        uint256 snapshotId = vm.snapshot();

        for (uint j = 0; j < methodRegistries.length; j++) {
            uint256 totalMethods = methodRegistries[j].supportedMethodsLength();

            for (uint256 i = 0; i < totalMethods; i++) {
                bytes4 methodSig = methodRegistries[j].supportedMethods(i);
                IMethodReentrancyTest method = methodRegistries[j].methods(methodSig);

                emit log_string(string.concat("\nExecute ", method.methodDescription()));

                method.callMethod();

                vm.revertTo(snapshotId);
            }
        }
    }

    function _deploySiloWithOverrides() internal {
        SiloFixture siloFixture = new SiloFixture();

        SiloConfigOverride memory configOverride;

        configOverride.token0 = address(new MaliciousToken());
        configOverride.token1 = address(new MaliciousToken());
        configOverride.configName = SiloConfigsNames.LOCAL_DEPLOYER;

        (ISiloConfig siloConfig, ISilo silo0, ISilo silo1,,,) = siloFixture.deploy_local(configOverride);

        TestStateLib.init(
            address(siloConfig),
            address(silo0),
            address(silo1),
            configOverride.token0,
            configOverride.token1
        );
    }
}
