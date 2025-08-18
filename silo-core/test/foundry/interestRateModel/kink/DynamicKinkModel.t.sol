// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {Ownable} from "openzeppelin5/access/Ownable.sol";

import {DynamicKinkModel, IDynamicKinkModel} from "../../../../contracts/interestRateModel/kink/DynamicKinkModel.sol";
import {IDynamicKinkModelConfig} from "../../../../contracts/interestRateModel/kink/DynamicKinkModelConfig.sol";
import {DynamicKinkModelFactory} from "../../../../contracts/interestRateModel/kink/DynamicKinkModelFactory.sol";

import {ISilo} from "../../../../contracts/interfaces/ISilo.sol";
import {KinkCommon} from "./KinkCommon.sol";

/* 
FOUNDRY_PROFILE=core_test forge test --mc DynamicKinkModelTest -vv
*/
contract DynamicKinkModelTest is KinkCommon {
    DynamicKinkModelFactory immutable FACTORY = new DynamicKinkModelFactory();

    mapping (bytes32 => bool) private seen;

    function setUp() public {
        IDynamicKinkModel.Config memory emptyConfig; 

        irm = DynamicKinkModel(address(FACTORY.create(emptyConfig, address(this), address(this), bytes32(0))));
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_initRevert_whenSiloZero -vv
    */
    function test_kink_initRevert_whenSiloZero() public {
        DynamicKinkModel newModel = new DynamicKinkModel();
        IDynamicKinkModel.Config memory config;

        vm.expectRevert(IDynamicKinkModel.EmptySilo.selector);
        newModel.initialize(config, address(this), address(0));
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_initRevert_whenAlreadyInitialized -vv
    */
    function test_kink_initRevert_whenAlreadyInitialized() public {
        IDynamicKinkModel.Config memory config;

        vm.expectRevert(IDynamicKinkModel.AlreadyInitialized.selector);
        irm.initialize(config, address(this), address(this));
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_getModelStateAndConfig_config -vv
    */
    function test_kink_getModelStateAndConfig_config_fuzz(
        RandomKinkConfig memory _config
    ) public whenValidConfig(_config) {
        IDynamicKinkModel.Config memory config = _toConfig(_config);
        irm.updateConfig(config);

        (, IDynamicKinkModel.Config memory c) = irm.getModelStateAndConfig();
        assertEq(_hashConfig(c), _hashConfig(config), "config is not the same");
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_getModelStateAndConfig_state -vv
    */
    function test_kink_getModelStateAndConfig_state() public {
        irm = DynamicKinkModel(address(FACTORY.create(_defaultConfig(), address(this), address(this), bytes32(0))));

        vm.warp(667222222);

        (IDynamicKinkModel.ModelState memory stateBefore,) = irm.getModelStateAndConfig();

        irm.getCompoundInterestRateAndUpdate({
            _collateralAssets: 445000000000000000000000000, 
            _debtAssets: 346111111111111116600547177, 
            _interestRateTimestamp: 445000000
        });

        (IDynamicKinkModel.ModelState memory stateAfter,) = irm.getModelStateAndConfig();

        assertLt(stateBefore.k, stateAfter.k, "k should change (grow)");
        assertEq(stateAfter.silo, address(this), "silo should be the same");
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_init_neverRevert_whenValidConfig -vv
    */
    function test_init_neverRevert_whenValidConfig_fuzz(
        RandomKinkConfig memory _config, 
        address _initialOwner,
        address _silo
    ) 
        public 
        whenValidConfig(_config) 
    {
        vm.assume(_silo != address(0));

        IDynamicKinkModel.Config memory config = _toConfig(_config);
        DynamicKinkModel newModel = new DynamicKinkModel();

        vm.expectEmit(true, true, true, true);
        emit IDynamicKinkModel.Initialized(_initialOwner, _silo);

        newModel.initialize(config, _initialOwner, _silo);

        _assertConfigEq(config, newModel.irmConfig().getConfig(), "init never revert");

        // re-init should revert
        vm.expectRevert(IDynamicKinkModel.AlreadyInitialized.selector);
        newModel.initialize(config, _initialOwner, _silo);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_updateConfigRevert_whenNotOwner -vv
    */
    function test_kink_updateConfigRevert_whenNotOwner() public {
        IDynamicKinkModel.Config memory config;
        address randomUser = makeAddr("RandomUser");

        vm.expectRevert(abi.encodeWithSelector(
            Ownable.OwnableUnauthorizedAccount.selector,
            randomUser
        ));

        vm.prank(randomUser);
        irm.updateConfig(config);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_updateConfig_fail_whenInvalidConfig -vv
    */
    function test_kink_updateConfig_fail_whenInvalidConfig_fuzz(
        IDynamicKinkModel.Config calldata _config
    ) public {
        vm.assume(!_isValidConfig(_config));

        vm.expectRevert();
        irm.updateConfig(_config);
    }

    /*
        FOUNDRY_PROFILE=core_test forge test --mt test_kink_updateConfig_multipleTimes -vv
    */
    function test_kink_updateConfig_multipleTimes_fuzz(
        RandomKinkConfig memory _config
    ) 
        public
        whenValidConfig(_config) 
    {
        _kink_updateConfig_pass(_toConfig(_config));
        _kink_updateConfig_pass(_toConfig(_config));
        _kink_updateConfig_pass(_toConfig(_config));
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_updateConfig_randomMultipleTimes_fuzz -vv
    */
    function test_kink_updateConfig_randomMultipleTimes_fuzz(
        RandomKinkConfig[10] memory _config
    ) public {
        
        for (uint256 i = 0; i < _config.length; i++) {
            IDynamicKinkModel.Config memory randomConfig = _toConfig(_config[i]);
            _makeConfigValid(randomConfig);

            bytes32 hash = _hashConfig(randomConfig);
            vm.assume(!seen[hash]);
            seen[hash] = true;
            
            _kink_updateConfig_pass(randomConfig);
        }
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_restoreLastConfig_revertWhenNoHistory -vv
    */
    function test_kink_restoreLastConfig_revertWhenNoHistory() public {
        vm.expectRevert(IDynamicKinkModel.AddressZero.selector);
        irm.restoreLastConfig();
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_restoreLastConfig_revertWhenNotOwner -vv
    */
    function test_kink_restoreLastConfig_revertWhenNotOwner() public {
        address randomUser = makeAddr("RandomUser");

        vm.expectRevert(abi.encodeWithSelector(
            Ownable.OwnableUnauthorizedAccount.selector,
            randomUser
        ));
        vm.prank(randomUser);
        irm.restoreLastConfig();
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_restoreLastConfig_fuzz -vv
    */
    function test_kink_restoreLastConfig_fuzz(RandomKinkConfig[10] memory _config) public {
        bytes32[] memory history = new bytes32[](_config.length);
        IDynamicKinkModelConfig[] memory historyAddrs = new IDynamicKinkModelConfig[](_config.length);
        
        IDynamicKinkModelConfig originalIrmConfig = irm.irmConfig();

        for (uint256 i = 0; i < _config.length; i++) {
            history[i] = _hashConfig(irm.irmConfig().getConfig());
            historyAddrs[i] = irm.irmConfig();

            IDynamicKinkModel.Config memory cfg = _toConfig(_config[i]);
            _makeConfigValid(cfg);
            
            _kink_updateConfig_pass(cfg);
        }

        for (uint256 k = 0; k < _config.length; k++) {
            uint256 i = _config.length - k - 1;
            vm.expectEmit(true, true, true, true);
            emit IDynamicKinkModel.ConfigRestored(historyAddrs[i]);

            console2.log("[%s] expected irm addr %s", i, address(historyAddrs[i]));
        
            irm.restoreLastConfig();
            console2.log("restored %s", i);

            assertEq(history[i], _hashConfig(irm.irmConfig().getConfig()), "config was not restored");
            assertEq(address(irm.irmConfig()), address(historyAddrs[i]), "irm config addr was not restored");
        }

        assertEq(address(irm.irmConfig()), address(originalIrmConfig), "irm config addr was not restored to the original");

        // at the end there is nothing more to restore
        vm.expectRevert(IDynamicKinkModel.AddressZero.selector);
        irm.restoreLastConfig();
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_getCompoundInterestRateAndUpdate_neverRevert -vv
    */
    /// forge-config: core_test.fuzz.runs = 1000
    function test_kink_getCompoundInterestRateAndUpdate_neverRevert_fuzz(
        RandomKinkConfig memory _config,
        uint256 _collateralAssets,
        uint256 _debtAssets,
        uint64 _interestRateTimestamp
    ) public {
        IDynamicKinkModel.Config memory cfg = _toConfig(_config);
        _makeConfigValid(cfg);

        irm.updateConfig(cfg);

        uint256 rcomp = irm.getCompoundInterestRateAndUpdate(_collateralAssets, _debtAssets, _interestRateTimestamp);

        if (_debtAssets == 0) assertEq(rcomp, 0, "[getCompoundInterestRateAndUpdate] rcomp is not 0 when no debt");

        assertTrue(
            rcomp >= 0 && rcomp <= uint256(irm.RCOMP_CAP()), 
            "[getCompoundInterestRateAndUpdate] rcomp out of range"
        );
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_getCompoundInterestRate_neverRevert -vv
    */
    /// forge-config: core_test.fuzz.runs = 1000
    function test_kink_getCompoundInterestRate_neverRevert_fuzz(
        RandomKinkConfig memory _config,
        ISilo.UtilizationData memory _utilizationData,
        uint256 _blockTimestamp
    ) public {
        vm.assume(_blockTimestamp >= _utilizationData.interestRateTimestamp);

        _setUtilizationData(_utilizationData);

        IDynamicKinkModel.Config memory cfg = _toConfig(_config);
        _makeConfigValid(cfg);

        irm.updateConfig(cfg);

        uint256 rcomp = irm.getCompoundInterestRate(address(this), _blockTimestamp);
        uint256 dT = _blockTimestamp - _utilizationData.interestRateTimestamp;

        console2.log("rcomp %s", rcomp);
        console2.log("dT %s", dT);

        if (dT == 0 || _utilizationData.debtAssets == 0) {
            assertEq(rcomp, 0, "[getCompoundInterestRate] rcomp is not 0 when dT == 0 OR no debt");
        } else {
            assertTrue(
                rcomp >= 0 && rcomp / dT <= uint256(irm.RCOMP_CAP()), 
                "[getCompoundInterestRate] rcomp out of range"
            );
        }
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_getCompoundInterestRate_revert_whenInvalidSilo -vv
    */
    function test_kink_getCompoundInterestRate_revert_whenInvalidSilo() public {
        vm.expectRevert(IDynamicKinkModel.InvalidSilo.selector);
        irm.getCompoundInterestRate(address(1), block.timestamp);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_getCurrentInterestRate_revert_whenInvalidSilo -vv
    */
    function test_kink_getCurrentInterestRate_revert_whenInvalidSilo() public {
        vm.expectRevert(IDynamicKinkModel.InvalidSilo.selector);
        irm.getCurrentInterestRate(address(1), block.timestamp);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_getCurrentInterestRate_neverRevert -vv
    */
    /// forge-config: core_test.fuzz.runs = 1000
    function test_kink_getCurrentInterestRate_neverRevert_fuzz(
        RandomKinkConfig memory _config,
        ISilo.UtilizationData memory _utilizationData,
        uint256 _blockTimestamp
    ) public {
        vm.assume(_blockTimestamp >= _utilizationData.interestRateTimestamp);

        _setUtilizationData(_utilizationData);

        IDynamicKinkModel.Config memory cfg = _toConfig(_config);
        _makeConfigValid(cfg);

        irm.updateConfig(cfg);

        uint256 rcur = irm.getCurrentInterestRate(address(this), _blockTimestamp);

        console2.log("rcur %s", rcur);

        if (_utilizationData.debtAssets == 0) assertEq(rcur, 0, "[getCurrentInterestRate] rcur is not 0 when no debt");
        else assertTrue(rcur >= 0 && rcur <= uint256(irm.RCUR_CAP()), "[getCurrentInterestRate] rcur out of range");
    }

    function _kink_updateConfig_pass(IDynamicKinkModel.Config memory _config) internal {
        IDynamicKinkModelConfig prevConfig = irm.irmConfig();

        uint256 nonce = vm.getNonce(address(irm));
        address newConfigAddress = vm.computeCreateAddress(address(irm), nonce);
        console2.log("newConfigAddress %s for nonce %s", newConfigAddress, nonce);

        vm.expectEmit(true, true, true, true);
        emit IDynamicKinkModel.NewConfig(IDynamicKinkModelConfig(newConfigAddress));

        irm.updateConfig(_config);
        _assertConfigEq(_config, irm.irmConfig().getConfig(), "updateConfig_pass");
        console2.log("config addr %s", address(irm.irmConfig()));

        assertEq(address(irm.configsHistory(irm.irmConfig())), address(prevConfig), "history is wrong");
    }
}
