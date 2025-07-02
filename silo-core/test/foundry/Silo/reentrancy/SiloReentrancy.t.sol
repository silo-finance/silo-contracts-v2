// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {Registries} from "./registries/Registries.sol";
import {IMethodsRegistry} from "./interfaces/IMethodsRegistry.sol";
import {MaliciousToken} from "./MaliciousToken.sol";
import {TestStateLib} from "./TestState.sol";
import {IMethodReentrancyTest} from "./interfaces/IMethodReentrancyTest.sol"; 
import {SiloFixture} from "../../_common/fixtures/SiloFixture.sol";
import {SiloConfigOverride} from "../../_common/fixtures/SiloFixture.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

// FOUNDRY_PROFILE=core_test forge test -vv --ffi --mc SiloReentrancyTest
contract SiloReentrancyTest is Test {
    ISiloConfig public siloConfig;
    
    // FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_coverage_for_reentrancy
    function test_coverage_for_reentrancy() public {
        Registries registries = new Registries();
        IMethodsRegistry[] memory methodRegistries = registries.list();

        bool allCovered = true;
        string memory root = vm.projectRoot();

        for (uint j = 0; j < methodRegistries.length; j++) {
            string memory abiPath = string.concat(root, methodRegistries[j].abiFile());
            string memory json = vm.readFile(abiPath);

            string[] memory keys = vm.parseJsonKeys(json, ".methodIdentifiers");

            for (uint256 i = 0; i < keys.length; i++) {
                bytes4 sig = bytes4(keccak256(bytes(keys[i])));
                address method = address(methodRegistries[j].methods(sig));

                if (method == address(0)) {
                    allCovered = false;

                    emit log_string(string.concat("\nABI: ", methodRegistries[j].abiFile()));
                    emit log_string(string.concat("Method not found: ", keys[i]));
                }
            }
        }

        assertTrue(allCovered, "All methods should be covered");
    }

    // FOUNDRY_PROFILE=core_test forge test -vvv --ffi --mt test_reentrancy
    function test_reentrancy() public {
        _deploySiloWithOverrides();
        Registries registries = new Registries();
        IMethodsRegistry[] memory methodRegistries = registries.list();

        emit log_string("\n\nRunning reentrancy test");

        uint256 stateBeforeTest = vm.snapshotState();

        for (uint j = 0; j < methodRegistries.length; j++) {
            uint256 totalMethods = methodRegistries[j].supportedMethodsLength();

            emit log_string(string.concat("\nVerifying ",methodRegistries[j].abiFile()));

            for (uint256 i = 0; i < totalMethods; i++) {
                bytes4 methodSig = methodRegistries[j].supportedMethods(i);
                IMethodReentrancyTest method = methodRegistries[j].methods(methodSig);

                emit log_string(string.concat("\nExecute ", method.methodDescription()));

                bool entered = siloConfig.reentrancyGuardEntered();
                assertTrue(!entered, "Reentrancy should be disabled before calling the method");

                method.callMethod();

                entered = siloConfig.reentrancyGuardEntered();
                assertTrue(!entered, "Reentrancy should be disabled after calling the method");

                vm.revertToState(stateBeforeTest);
            }
        }
    }

    function _deploySiloWithOverrides() internal {
        SiloFixture siloFixture = new SiloFixture();

        SiloConfigOverride memory configOverride;

        configOverride.token0 = address(new MaliciousToken());
        configOverride.token1 = address(new MaliciousToken());
        configOverride.configName = SiloConfigsNames.SILO_LOCAL_GAUGE_HOOK_RECEIVER;
        ISilo silo0;
        ISilo silo1;
        address hookReceiver;

        (siloConfig, silo0, silo1,,, hookReceiver) = siloFixture.deploy_local(configOverride);

        TestStateLib.init(
            address(siloConfig),
            address(silo0),
            address(silo1),
            configOverride.token0,
            configOverride.token1,
            hookReceiver
        );
    }
}
