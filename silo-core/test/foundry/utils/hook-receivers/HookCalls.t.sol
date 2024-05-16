// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {SiloFixture, SiloConfigOverride} from "../../_common/fixtures/SiloFixture.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IHookReceiver} from "silo-core/contracts/utils/hook-receivers/interfaces/IHookReceiver.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";

import {SiloLittleHelper} from  "../../_common/SiloLittleHelper.sol";
import {MintableToken} from "../../_common/MintableToken.sol";

/*
FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc HookCallsTest
*/
contract HookCallsTest is IHookReceiver, SiloLittleHelper, Test {
    ISiloConfig internal _siloConfig;

    function setUp() public {
        token0 = new MintableToken(6);
        token1 = new MintableToken(18);

        SiloConfigOverride memory overrides;
        overrides.token0 = address(token0);
        overrides.token1 = address(token1);
        overrides.hookReceiver = address(this);

        SiloFixture siloFixture = new SiloFixture();
        (_siloConfig, silo0, silo1,,, partialLiquidation) = siloFixture.deploy_local(overrides);
    }

    // FOUNDRY_PROFILE=core-test forge test --ffi -vvv --mt testReinitialization
    function test_ifHooksAreNotCalledInsideAction() public {
        // TODO
    }

    function initialize(ISiloConfig _config, bytes calldata _data) external {
        assertEq(address(_siloConfig), address(_config), "SiloConfig addresses should match");
    }

    /// @notice state of Silo before action, can be also without interest, if you need them, call silo.accrueInterest()
    function beforeAction(address _silo, uint256 _action, bytes calldata _input) external {
        assertFalse(_siloConfig.crossReentrancyGuardEntered(), "hook before must be called before any action");
    }

    function afterAction(address _silo, uint256 _action, bytes calldata _inputAndOutput) external {
        assertFalse(_siloConfig.crossReentrancyGuardEntered(), "hook after must be called after any action");
    }

    /// @notice return hooksBefore and hooksAfter configuration
    function hookReceiverConfig(address _silo) external view returns (uint24 hooksBefore, uint24 hooksAfter) {
        // we want all possible combinations to be ON
        hooksBefore = type(uint24).max;
        hooksAfter = type(uint24).max;
    }
}
