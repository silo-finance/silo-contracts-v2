// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {HookReceiverMock} from "silo-core/test/foundry/_mocks/HookReceiverMock.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {SiloFixture, SiloConfigOverride} from "../_common/fixtures/SiloFixture.sol";
import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";
import {ContractThatAcceptsETH} from "silo-core/test/foundry/_mocks/ContractThatAcceptsETH.sol";

/// FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mc SiloHooksTest
contract SiloHooksTest is SiloLittleHelper, Test {
    uint24 constant HOOKS_BEFORE = 1;
    uint24 constant HOOKS_AFTER = 2;
 
    HookReceiverMock internal _hookReceiverMock;
    ISiloConfig internal _siloConfig;

    address thridParty = makeAddr("ThirdParty");
    address hookReceiverAddr;

    function setUp() public {
        SiloFixture siloFixture = new SiloFixture();
        SiloConfigOverride memory configOverride;

        _hookReceiverMock = new HookReceiverMock(address(0));
        _hookReceiverMock.hookReceiverConfigMock(HOOKS_BEFORE, HOOKS_AFTER);

        hookReceiverAddr = _hookReceiver.ADDRESS();

        configOverride.token0 = makeAddr("token0");
        configOverride.token1 = makeAddr("token1");
        configOverride.hookReceiver = hookReceiverAddr;
        configOverride.configName = SiloConfigsNames.LOCAL_DEPLOYER;

        (_siloConfig, silo0, silo1,,,) = siloFixture.deploy_local(configOverride);
    }

    function testHooksInitializationAfterDeployment() public {
        (,uint24 silo0HookesBefore, uint24 silo0HookesAfter,) = silo0.sharedStorage();

        assertEq(silo0HookesBefore, HOOKS_BEFORE, "hooksBefore is not initailized");
        assertEq(silo0HookesAfter, HOOKS_AFTER, "hooksAfter is not initailized");

        (,uint24 silo1HookesBefore, uint24 silo1HookesAfter,) = silo1.sharedStorage();

        assertEq(silo1HookesBefore, HOOKS_BEFORE, "hooksBefore is not initailized");
        assertEq(silo1HookesAfter, HOOKS_AFTER, "hooksAfter is not initailized");
    }

    /// FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testHooksUpdate
    function testHooksUpdate() public {
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

    /// FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testCallOnBehalfOfSilo
    function testCallOnBehalfOfSilo() public {
        (address protectedShareToken,,) = _siloConfig.getShareTokens(address(silo0));

        uint256 tokensToMint = 100;
        bytes memory data = abi.encodeWithSelector(IShareToken.mint.selector, thridParty, thridParty, tokensToMint);

        vm.expectRevert(ISilo.OnlyHookReceiver.selector);
        silo0.callOnBehalfOfSilo(protectedShareToken, data);

        assertEq(IERC20(protectedShareToken).balanceOf(thridParty), 0);

        vm.prank(hookReceiverAddr);
        silo0.callOnBehalfOfSilo(protectedShareToken, data);

        assertEq(IERC20(protectedShareToken).balanceOf(thridParty), tokensToMint);
    }

    /// FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testCallOnBehalfOfSiloWithETH
    function testCallOnBehalfOfSiloWithETH() public {
        address target = address(new ContractThatAcceptsETH());
        bytes memory data = abi.encodeWithSelector(ContractThatAcceptsETH.anyFunction.selector);

        assertEq(target.balance, 0, "Expect to have no balance");

        uint256 amoutToSend = 1 ether;

        vm.deal(hookReceiverAddr, amoutToSend);
        vm.prank(hookReceiverAddr);
        silo0.callOnBehalfOfSilo{value: amoutToSend}(target, data);

        assertEq(target.balance, amoutToSend, "Expect to have non zero balance");
    }

    /// FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testCallOnBehalfOfSiloWithETHleftover
    function testCallOnBehalfOfSiloWithETHleftover() public {
        address target = address(new ContractThatAcceptsETH());
        bytes memory data = abi.encodeWithSelector(ContractThatAcceptsETH.anyFunctionThatSendEthBack.selector);

        assertEq(target.balance, 0, "Expect to have no balance");

        uint256 amoutToSend = 1 ether;

        vm.deal(hookReceiverAddr, amoutToSend);
        vm.prank(hookReceiverAddr);
        silo0.callOnBehalfOfSilo{value: amoutToSend}(target, data);

        assertEq(hookReceiverAddr.balance, amoutToSend, "Expect to have non zero balance");
    }
}
