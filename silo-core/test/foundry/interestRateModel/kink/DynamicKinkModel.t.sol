// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";
import {SignedMath} from "openzeppelin5/utils/math/SignedMath.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";

import {DynamicKinkModel, IDynamicKinkModel} from "../../../../contracts/interestRateModel/kink/DynamicKinkModel.sol";
import {DynamicKinkModelConfig, IDynamicKinkModelConfig} from "../../../../contracts/interestRateModel/kink/DynamicKinkModelConfig.sol";
import {DynamicKinkModelFactory} from "../../../../contracts/interestRateModel/kink/DynamicKinkModelFactory.sol";

import {ISilo} from "../../../../contracts/interfaces/ISilo.sol";

/* 
FOUNDRY_PROFILE=core_test forge test --mc DynamicKinkModelTest -vv
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

        irm = DynamicKinkModel(address(FACTORY.create(emptyConfig, address(this), address(this))));
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
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_updateConfig_randomMultipleTimes -vv

    with RandomKinkConfig[] fuzzing fails because it is to hard to find valid configs
    */
    function test_kink_updateConfig_randomMultipleTimes_fuzz(
        RandomKinkConfig memory _config, 
        uint64[10] memory _randomizers
    ) public whenValidConfig(_config) {
        _kink_updateConfig_pass(_toConfig(_config));

        for (uint256 i = 0; i < _randomizers.length; i++) {
            console2.log("randomizer %s of %s", i, _randomizers.length);
            IDynamicKinkModel.Config memory randomConfig = _randomizeConfig(_config, _randomizers[i]);
            _makeConfigValid(randomConfig);
            
            _kink_updateConfig_pass(randomConfig);
        }
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

    function _randomizeConfig(
        RandomKinkConfig memory _config, 
        uint128 _randomizer
    ) internal pure returns (IDynamicKinkModel.Config memory cfg) {
        cfg = _toConfig(RandomKinkConfig({
            ulow: _generateRandomNumber64(_config.ulow, _randomizer),
            u1: _generateRandomNumber64(_config.u1, _randomizer),
            u2: _generateRandomNumber64(_config.u2, _randomizer),
            ucrit: _generateRandomNumber64(_config.ucrit, _randomizer),
            rmin: _generateRandomNumber64(_config.rmin, _randomizer),
            kmin: _generateRandomNumber96(_config.kmin, _randomizer),
            kmax: _generateRandomNumber96(_config.kmax, _randomizer),
            alpha: _generateRandomNumber96(_config.alpha, _randomizer),
            cminus: _generateRandomNumber96(_config.cminus, _randomizer),
            cplus: _generateRandomNumber96(_config.cplus, _randomizer),
            c1: _generateRandomNumber96(_config.c1, _randomizer),
            c2: _generateRandomNumber96(_config.c2, _randomizer),
            dmax: _generateRandomNumber96(_config.dmax, _randomizer)
        }));
    }

    function _makeConfigValid(IDynamicKinkModel.Config memory _config) internal pure {
        _config.ulow = _getBetween(_config.ulow, 0, _config.u1);
        _config.u1 = _getBetween(_config.u1, 0, _DP);
        _config.u2 = _getBetween(_config.u2, _config.u1, _DP);
        _config.ucrit = _getBetween(_config.ucrit, _config.u2, _DP);
        _config.rmin = _getBetween(_config.rmin, 0, _DP);
        _config.kmin = int96(_getBetween(_config.kmin, 0, UNIVERSAL_LIMIT));
        _config.kmax = int96(_getBetween(_config.kmax, _config.kmin, UNIVERSAL_LIMIT));
        _config.alpha = _getBetween(_config.alpha, 0, UNIVERSAL_LIMIT);
        _config.cminus = _getBetween(_config.cminus, 0, UNIVERSAL_LIMIT);
        _config.cplus = _getBetween(_config.cplus, 0, UNIVERSAL_LIMIT);
        _config.c1 = _getBetween(_config.c1, 0, UNIVERSAL_LIMIT);
        _config.c2 = _getBetween(_config.c2, 0, UNIVERSAL_LIMIT);
        _config.dmax = _getBetween(_config.dmax, _config.c2, UNIVERSAL_LIMIT);
    }

    function _getBetween(int256 _n, int256 _min, int256 _max) internal pure returns (int256) {
        return SignedMath.max(SignedMath.min(_n, _max), _min);
    }

    function _generateRandomNumber64(uint64 _n, uint128 _modulo) internal pure returns (uint64) {
        if (_modulo == 0) return _n;
        return uint64((uint128(_n) % _modulo) % uint64(type(uint64).max));
    }

    function _generateRandomNumber96(uint96 _n, uint128 _modulo) internal pure returns (uint96) {
        if (_modulo == 0) return _n;
        return uint96((uint128(_n) % _modulo) % uint96(type(uint96).max));
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
