// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin5/access/Ownable.sol";

import {DynamicKinkModel, IDynamicKinkModel} from "../../../../contracts/interestRateModel/kink/DynamicKinkModel.sol";
import {IDynamicKinkModelConfig} from "../../../../contracts/interestRateModel/kink/DynamicKinkModelConfig.sol";
import {DynamicKinkModelFactory} from "../../../../contracts/interestRateModel/kink/DynamicKinkModelFactory.sol";

import {KinkCommonTest} from "./KinkCommon.t.sol";
import {DynamicKinkModelMock} from "./DynamicKinkModelMock.sol";

/* 
FOUNDRY_PROFILE=core_test forge test --mc DynamicKinkModelTimelockTest -vv
*/
contract DynamicKinkModelTimelockTest is KinkCommonTest {
    address silo = address(this);

    function setUp() public {
        vm.warp(100);

        IDynamicKinkModel.Config memory emptyConfig;
        IDynamicKinkModel.ImmutableArgs memory immutableArgs =
            IDynamicKinkModel.ImmutableArgs({timelock: 1 days, rcompCap: 1});

        irm = DynamicKinkModel(address(FACTORY.create(emptyConfig, immutableArgs, address(this), silo, bytes32(0))));
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_initialConfig_isActivatedImmediately -vv
    */
    function test_kink_initialConfig_isActivatedImmediately() public {
        assertEq(_getIRMImmutableConfig(irm).timelock, 1 days, "expect timelock for this test");

        assertEq(irm.activateConfigAt(), block.timestamp, "activateConfigAt should be equal to tx timestamp");
        assertEq(irm.pendingIrmConfig(), address(0), "there should be no pending config");

        // there should be nothing to cancel
        vm.expectRevert(IDynamicKinkModel.NoPendingUpdateToCancel.selector);
        irm.cancelPendingUpdateConfig();
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_timelock_revert -vv
    */
    function test_kink_timelock_revert() public {
        IDynamicKinkModel.Config memory config;
        IDynamicKinkModel.ImmutableArgs memory immutableArgs =
            IDynamicKinkModel.ImmutableArgs({timelock: 7 days + 1, rcompCap: 1});

        vm.expectRevert(IDynamicKinkModel.InvalidTimelock.selector);
        FACTORY.create(config, immutableArgs, address(this), silo, bytes32(0));
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_pendingUpdateConfig_pass -vv
    */
    function test_kink_pendingUpdateConfig_pass() public {
        IDynamicKinkModel.Config memory config;
        config.ucrit = _getIRMConfig(irm).ucrit + 1; // make sure new config is different

        address prevIrmConfig = address(irm.irmConfig());

        vm.expectEmit(false, false, false, false);
        emit IDynamicKinkModel.NewConfig(IDynamicKinkModelConfig(address(0)), block.timestamp + 1 days);

        irm.updateConfig(config);

        address pendingIrmConfig = irm.pendingIrmConfig();

        assertNotEq(pendingIrmConfig, address(0), "pendingIrmConfig exists");
        assertEq(irm.activateConfigAt(), block.timestamp + 1 days, "activateConfigAt is not correct");

        _assertModelWorksWithDesiredConfig(prevIrmConfig);

        vm.expectCall(pendingIrmConfig, abi.encodeWithSelector(IDynamicKinkModelConfig.getConfig.selector));
        irm.getModelStateAndConfig(true);

        vm.expectCall(pendingIrmConfig, abi.encodeWithSelector(IDynamicKinkModelConfig.getConfig.selector));
        irm.getPendingCurrentInterestRate(silo, block.timestamp);

        vm.expectCall(pendingIrmConfig, abi.encodeWithSelector(IDynamicKinkModelConfig.getConfig.selector));
        irm.getPendingCompoundInterestRate(silo, block.timestamp);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_pendingConfig_isActivatedAtTimelock -vv
    */
    function test_kink_pendingConfig_isActivatedAtTimelock() public {
        IDynamicKinkModel.Config memory config;
        config.ucrit = _getIRMConfig(irm).ucrit + 1; // make sure new config is different

        address prevIrmConfig = address(irm.irmConfig());

        irm.updateConfig(config);

        address pendingIrmConfig = irm.pendingIrmConfig();

        _assertCorrectHistory(IDynamicKinkModelConfig(pendingIrmConfig), IDynamicKinkModelConfig(prevIrmConfig));

        vm.warp(block.timestamp + 1 days);

        // QA

        vm.expectRevert(IDynamicKinkModel.NoPendingUpdateToCancel.selector);
        irm.cancelPendingUpdateConfig();

        assertEq(irm.pendingIrmConfig(), address(0), "pendingIrmConfig should be 0 at this point");
        assertEq(irm.activateConfigAt(), block.timestamp, "activateConfigAt should be equal to block.timestamp");

        _assertModelWorksWithDesiredConfig(pendingIrmConfig);
    }

    /*
        FOUNDRY_PROFILE=core_test forge test --mt test_kink_cancelPendingUpdateConfig_onlyOwner -vv
    */
    function test_kink_cancelPendingUpdateConfig_onlyOwner() public {
        vm.prank(address(1));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(1)));

        irm.cancelPendingUpdateConfig();
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_cancelPendingUpdateConfig_pass -vv
    */
    function test_kink_cancelPendingUpdateConfig_pass() public {
        IDynamicKinkModel.Config memory config;
        config.ucrit = _getIRMConfig(irm).ucrit + 1; // make sure new config is different

        address prevIrmConfig = address(irm.irmConfig());

        vm.expectEmit(false, false, false, false);
        emit IDynamicKinkModel.NewConfig(IDynamicKinkModelConfig(address(0)), block.timestamp + 1 days);

        irm.updateConfig(config);
        vm.warp(block.timestamp + 1 days - 1);

        irm.cancelPendingUpdateConfig();

        assertEq(irm.pendingIrmConfig(), address(0), "pendingIrmConfig should be 0 at this point");
        assertEq(irm.activateConfigAt(), 0, "activateConfigAt should be reset to 0");

        _assertModelWorksWithDesiredConfig(prevIrmConfig);

        _assertCorrectHistory(IDynamicKinkModelConfig(prevIrmConfig), IDynamicKinkModelConfig(address(0)));
    }

    function _assertModelWorksWithDesiredConfig(address _irmConfig) internal {
        assertEq(address(irm.irmConfig()), _irmConfig, "undexpected irm.irmConfig()");

        // expect calls to _irmConfig

        vm.expectCall(_irmConfig, abi.encodeWithSelector(IDynamicKinkModelConfig.getConfig.selector));
        irm.getModelStateAndConfig(false);

        vm.expectCall(_irmConfig, abi.encodeWithSelector(IDynamicKinkModelConfig.getConfig.selector));
        irm.getCompoundInterestRate(silo, block.timestamp);

        vm.expectCall(_irmConfig, abi.encodeWithSelector(IDynamicKinkModelConfig.getConfig.selector));
        irm.getCurrentInterestRate(silo, block.timestamp);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_pendingConfigExists -vv
    */
    function test_kink_pendingConfigExists() public {
        IDynamicKinkModel.Config memory cfg;

        assertFalse(irm.pendingConfigExists(), "pendingConfigExists should be false at beginning");

        irm.updateConfig(cfg);
        assertTrue(irm.pendingConfigExists(), "pendingConfigExists should be true when update is called");

        irm.cancelPendingUpdateConfig();
        assertFalse(irm.pendingConfigExists(), "pendingConfigExists should be false after cancel");

        irm.updateConfig(cfg);
        vm.warp(block.timestamp + 1 days - 1);
        assertTrue(irm.pendingConfigExists(), "pendingConfigExists should be true before timelock");

        vm.warp(block.timestamp + 1);
        assertTrue(irm.pendingConfigExists(), "pendingConfigExists should be FALSE after timelock");
    }
}
