// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";

import {DynamicKinkModel, IDynamicKinkModel} from "../../../../contracts/interestRateModel/kink/DynamicKinkModel.sol";
import {DynamicKinkModelConfig} from "../../../../contracts/interestRateModel/kink/DynamicKinkModelConfig.sol";
import {DynamicKinkModelFactory} from "../../../../contracts/interestRateModel/kink/DynamicKinkModelFactory.sol";

import {ISilo} from "../../../../contracts/interfaces/ISilo.sol";

/* 
FOUNDRY_PROFILE=core_test forge test -vv --mc DynamicKinkModelTest
*/
contract DynamicKinkModelTest is Test {
    struct RandomKinkConfig {
        uint64 ulow;
        uint64 u1;
        uint64 u2;
        uint64 ucrit;
        uint64 rmin;
        uint96 kmin;
        uint96 kmax;
        uint96 alpha;
        uint96 cminus;
        uint96 cplus;
        uint96 c1;
        uint96 c2;
        uint96 dmax;
    }

    DynamicKinkModelFactory immutable FACTORY = new DynamicKinkModelFactory();
    DynamicKinkModel irm;

    int256 constant _DP = 10 ** 18;
    int256 public constant UNIVERSAL_LIMIT = 1e9 * _DP;

    ISilo.UtilizationData public utilizationData;

    modifier whenValidConfig(RandomKinkConfig memory _config) {
        bool valid = _isValidConfig(_config);
        vm.assume(valid);

        _;
    }

    function setUp() public {
        IDynamicKinkModel.Config memory emptyConfig; 
        // IDynamicKinkModel.Config({
        //     ulow: 0,
        //     u1: 0,
        //     u2: 0,
        //     ucrit: 0,
        //     rmin: 0,
        //     kmin: 0,
        //     kmax: 0,
        //     alpha: 0,
        //     cminus: 0,
        //     cplus: 0,
        //     c1: 0,
        //     c2: 0,
        //     dmax: 0
        // });

        irm = DynamicKinkModel(address(FACTORY.create(emptyConfig, address(this), address(this))));
    }

    /* 
    FOUNDRY_PROFILE=core_test forge test -vv --mt test_kink_emptyConfigPass
    */
    function test_kink_emptyConfigPass(IDynamicKinkModel.Config calldata _config) public view {
        // pass
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --mt test_kink_initRevert_whenSiloZero
    */
    function test_kink_initRevert_whenSiloZero() public {
        DynamicKinkModel newModel = new DynamicKinkModel();
        IDynamicKinkModel.Config memory config;

        vm.expectRevert(IDynamicKinkModel.EmptySilo.selector);
        newModel.initialize(config, address(this), address(0));
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --mt test_kink_initRevert_whenAlreadyInitialized
    */
    function test_kink_initRevert_whenAlreadyInitialized() public {
        IDynamicKinkModel.Config memory config;

        vm.expectRevert(IDynamicKinkModel.AlreadyInitialized.selector);
        irm.initialize(config, address(this), address(this));
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --mt test_init_neverRevert_whenValidConfig
    */
    function test_init_neverRevert_whenValidConfig(
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
        newModel.initialize(config, _initialOwner, _silo);

        _assertConfigEq(config, newModel.irmConfig().getConfig(), "init never revert");

        vm.expectRevert(IDynamicKinkModel.AlreadyInitialized.selector);
        newModel.initialize(config, _initialOwner, _silo);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --mt test_kink_updateConfigRevert_whenNotOwner
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
    FOUNDRY_PROFILE=core_test forge test -vv --mt test_kink_updateConfig_fail_whenInvalidConfig
    */
    function test_kink_updateConfig_fail_whenInvalidConfig(IDynamicKinkModel.Config calldata _config) public {
        vm.assume(!_isValidConfig(_config));

        vm.expectRevert();
        irm.updateConfig(_config);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --mt test_kink_updateConfig_pass
    */
    function test_kink_updateConfig_pass(RandomKinkConfig memory _config) public whenValidConfig(_config) {
        IDynamicKinkModel.Config memory config = _toConfig(_config);

        irm.updateConfig(config);
        _assertConfigEq(config, irm.irmConfig().getConfig(), "updateConfig_pass");
    }

    function _isValidConfig(RandomKinkConfig memory _config) 
        internal 
        view 
        returns (bool valid) 
    {
        try irm.verifyConfig(_toConfig(_config)) {
            valid = true;
        } catch {
            valid = false;
        }
    }

    function _isValidConfig(IDynamicKinkModel.Config calldata _config) 
        internal 
        view 
        returns (bool valid) 
    {
        try irm.verifyConfig(_config) {
            valid = true;
        } catch {
            valid = false;
        }
    }

    function _toConfig(RandomKinkConfig memory _config) internal pure returns (IDynamicKinkModel.Config memory) {
        return IDynamicKinkModel.Config({
            ulow: SafeCast.toInt256(uint256(_config.ulow)),
            u1: SafeCast.toInt256(uint256(_config.u1)),
            u2: SafeCast.toInt256(uint256(_config.u2)),
            ucrit: SafeCast.toInt256(uint256(_config.ucrit)),
            rmin: SafeCast.toInt256(uint256(_config.rmin)),
            // we need to modulo, because on both sides we have 96 bits,
            // in order not to use vm.assume or require, we bound random value
            kmin: int96(_config.kmin % uint96(type(int96).max)),
            kmax: int96(_config.kmax % uint96(type(int96).max)),
            alpha: SafeCast.toInt256(uint256(_config.alpha)),
            cminus: SafeCast.toInt256(uint256(_config.cminus)),
            cplus: SafeCast.toInt256(uint256(_config.cplus)),
            c1: SafeCast.toInt256(uint256(_config.c1)),
            c2: SafeCast.toInt256(uint256(_config.c2)),
            dmax: SafeCast.toInt256(uint256(_config.dmax))
        });
    }

    function _assertConfigEq(
        IDynamicKinkModel.Config memory _config1, 
        IDynamicKinkModel.Config memory _config2,
        string memory _name
    ) internal pure {
        assertEq(_config1.ulow, _config2.ulow, string.concat("[", _name, "] ulow does not match"));
        assertEq(_config1.u1, _config2.u1, string.concat("[", _name, "] u1 does not match"));
        assertEq(_config1.u2, _config2.u2, string.concat("[", _name, "] u2 does not match"));
        assertEq(_config1.ucrit, _config2.ucrit, string.concat("[", _name, "] ucrit does not match"));
        assertEq(_config1.rmin, _config2.rmin, string.concat("[", _name, "] rmin does not match"));
        assertEq(_config1.kmin, _config2.kmin, string.concat("[", _name, "] kmin does not match"));
        assertEq(_config1.kmax, _config2.kmax, string.concat("[", _name, "] kmax does not match"));
        assertEq(_config1.alpha, _config2.alpha, string.concat("[", _name, "] alpha does not match"));
        assertEq(_config1.cminus, _config2.cminus, string.concat("[", _name, "] cminus does not match"));
        assertEq(_config1.cplus, _config2.cplus, string.concat("[", _name, "] cplus does not match"));
        assertEq(_config1.c1, _config2.c1, string.concat("[", _name, "] c1 does not match"));
        assertEq(_config1.c2, _config2.c2, string.concat("[", _name, "] c2 does not match"));
        assertEq(_config1.dmax, _config2.dmax, string.concat("[", _name, "] dmax does not match"));
    }
}
