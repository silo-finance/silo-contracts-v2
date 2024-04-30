// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {HookReceiverMock} from "silo-core/test/foundry/_mocks/HookReceiverMock.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {SiloFixture, SiloConfigOverride} from "../_common/fixtures/SiloFixture.sol";
import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

/// FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mc SiloHooksTest
contract SiloHooksTest is SiloLittleHelper, Test {
    uint24 constant HOOKS_BEFORE = 1;
    uint24 constant HOOKS_AFTER = 2;
 
    HookReceiverMock internal _hookReceiver;
    SiloFixture internal _siloFixture;

    SiloConfigOverride internal _overrides;

    function setUp() public {
        _hookReceiver = new HookReceiverMock(address(0));
        _hookReceiver.hookReceiverConfigMock(HOOKS_BEFORE, HOOKS_AFTER);

        _overrides.token0 = makeAddr("token0");
        _overrides.token1 = makeAddr("token1");
        _overrides.hookReceiver = _hookReceiver.ADDRESS();
        _overrides.configName = SiloConfigsNames.LOCAL_DEPLOYER;

        _siloFixture = new SiloFixture();
    }

    function testHooksInitializationAfterDeployment() public {
        (,ISilo silo0, ISilo silo1,,,) = _siloFixture.deploy_local(_overrides);

        (,uint24 silo0HookesBefore, uint24 silo0HookesAfter,) = silo0.sharedStorage();

        assertEq(silo0HookesBefore, HOOKS_BEFORE, "hooksBefore is not initailized");
        assertEq(silo0HookesAfter, HOOKS_AFTER, "hooksAfter is not initailized");

        (,uint24 silo1HookesBefore, uint24 silo1HookesAfter,) = silo1.sharedStorage();

        assertEq(silo1HookesBefore, HOOKS_BEFORE, "hooksBefore is not initailized");
        assertEq(silo1HookesAfter, HOOKS_AFTER, "hooksAfter is not initailized");
    }

    function testHooksUpdate() public {
        (,ISilo silo0, ISilo silo1,,,) = _siloFixture.deploy_local(_overrides);

        uint24 newHooksBefore = 3;
        uint24 newHooksAfter = 4;

        _hookReceiver.hookReceiverConfigMock(newHooksBefore, newHooksAfter);

        silo0.updateHooks();

        (,uint24 silo0HookesBefore, uint24 silo0HookesAfter,) = silo0.sharedStorage();

        assertEq(silo0HookesBefore, newHooksBefore, "hooksBefore is not updated");
        assertEq(silo0HookesAfter, newHooksAfter, "hooksAfter is not updated");

        silo1.updateHooks();

        (,uint24 silo1HookesBefore, uint24 silo1HookesAfter,) = silo1.sharedStorage();

        assertEq(silo1HookesBefore, newHooksBefore, "hooksBefore is not updated");
        assertEq(silo1HookesAfter, newHooksAfter, "hooksAfter is not updated");
    }
}
