// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {Math} from "openzeppelin5/utils/math/Math.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";

import {RevertLib} from "silo-core/contracts/lib/RevertLib.sol";

import {DynamicKinkModel, IDynamicKinkModel} from "../../../../contracts/interestRateModel/kink/DynamicKinkModel.sol";
import {IDynamicKinkModelConfig} from "../../../../contracts/interestRateModel/kink/DynamicKinkModelConfig.sol";
import {DynamicKinkModelFactory} from "../../../../contracts/interestRateModel/kink/DynamicKinkModelFactory.sol";
import {IDynamicKinkModelFactory} from "../../../../contracts/interfaces/IDynamicKinkModelFactory.sol";
import {IInterestRateModel} from "../../../../contracts/interfaces/IInterestRateModel.sol";

import {ISilo} from "../../../../contracts/interfaces/ISilo.sol";
import {KinkCommon} from "./KinkCommon.sol";

import {RandomLib} from "../../_common/RandomLib.sol";


/* 
FOUNDRY_PROFILE=core_test forge test --mc DynamicKinkModelFactoryTest -vv
*/
contract DynamicKinkModelFactoryTest is KinkCommon {
    using RandomLib for uint256;
    using RandomLib for uint72;
    using RandomLib for uint64;
    using RandomLib for uint32;

    uint256 constant DP = 1e18;

    DynamicKinkModelFactory immutable FACTORY = new DynamicKinkModelFactory();

    function setUp() public {
        IDynamicKinkModel.Config memory emptyConfig;
        irm = DynamicKinkModel(address(FACTORY.create(emptyConfig, address(this), address(this), bytes32(0))));
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_create_revertOnInvalidConfig -vv
    */
    function test_kink_create_revertOnInvalidConfig(IDynamicKinkModel.Config memory _config) public {
        vm.assume(!_isValidConfig(_config));

        vm.expectRevert();
        FACTORY.create(_config, address(this), address(this), bytes32(0));
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_predictAddress_pass -vv
    */
    function test_kink_predictAddress_pass(
        RandomKinkConfig memory _config, 
        address _deployer, 
        bytes32 _externalSalt
    ) public whenValidConfig(_config) {
        address predictedAddress = FACTORY.predictAddress(_deployer, _externalSalt);
        IDynamicKinkModel.Config memory config = _toConfig(_config);
        FACTORY.verifyConfig(config);

        vm.prank(_deployer);
        IInterestRateModel deployedIrm = FACTORY.create(config, address(this), address(this), _externalSalt);

        assertEq(predictedAddress, address(deployedIrm), "predicted address is not the same as the deployed address");
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_create_pass -vv
    */
    function test_kink_create_pass(RandomKinkConfig memory _config) public whenValidConfig(_config) {
        address predictedAddress = FACTORY.predictAddress(address(this), bytes32(0));   

        vm.expectEmit(true, true, true, true);
        emit IDynamicKinkModelFactory.NewDynamicKinkModel(IDynamicKinkModel(predictedAddress));

        FACTORY.create(_toConfig(_config), address(this), address(this), bytes32(0));

        assertTrue(FACTORY.createdByFactory(predictedAddress));
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_generateConfig_manual -vv
    */
    function test_kink_generateConfig_manual() public view {
        FACTORY.generateConfig(_exampleOfUserFriendlyConfig_1());
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_generateConfig_alwaysWorks -vv
    */
    function test_kink_generateConfig_alwaysWorks(
        IDynamicKinkModel.UserFriendlyConfig memory _in
        ) public view {
               
        // bytes memory callData = hex"00000000000000000000000000000000000000000000000008d97676bb12ca4e00000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000e4e000000000000000000000000000000000000000000000000fffffffffffffffc00000000000000000000000000000000000000000000000002fedbb19c51b7d10000000000000000000000000000000000000000000000000000029ae8ab919b000000000000000000000000000000000000000000000000000000bdf77ce59f0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000d000000000000000000000000000000000000000000000000000000000000c1270000000000000000000000000000000000000000000000000000000000000cb40000000000000000000000000000000000000000000000000000000001d9ed6f00000000000000000000000000000000000000000000000000000000fffffffe";
        // IDynamicKinkModel.UserFriendlyConfig memory _in = abi.decode(callData, (IDynamicKinkModel.UserFriendlyConfig));

        _printUserFriendlyConfig(_in);

        // start help fuzzing ----------------------------
        // with straight config as input, we fail with too many rejection, so we need to "help" to build config that will pass
        _applyReasonableLimits(_in);
        // end help fuzzing ------------------------------

        _printUserFriendlyConfig(_in);

        try FACTORY.generateConfig(_in) returns (IDynamicKinkModel.Config memory config) {
            FACTORY.verifyConfig(config);
            revert("OK!!!!");
        } catch (bytes memory revertData) {
            bytes32 revertHash = keccak256(revertData);

            // we only accept InvalidDefaultConfig or AlphaDividerZero errors, any other error is a failure
            if (revertHash == keccak256(abi.encodeWithSelector(IDynamicKinkModel.InvalidDefaultConfig.selector))) {
                vm.assume(false);
            } else if (revertHash == keccak256(abi.encodeWithSelector(IDynamicKinkModel.AlphaDividerZero.selector))) {
                vm.assume(false);
            } else {
                                vm.assume(false);

                RevertLib.revertBytes(revertData, "Unknown error");
            }
        }
    }

    function _printUserFriendlyConfig(IDynamicKinkModel.UserFriendlyConfig memory _in) internal pure {
        console2.log("--------------------------------");
        console2.log("ulow", _in.ulow);
        console2.log("ucrit", _in.ucrit);
        console2.log("u1", _in.u1);
        console2.log("u2", _in.u2);
        console2.log("rmin", _in.rmin);
        console2.log("rcritMin", _in.rcritMin);
        console2.log("rcritMax", _in.rcritMax);
        console2.log("r100", _in.r100);
        console2.log("t1", _in.t1);
        console2.log("t2", _in.t2);
        console2.log("tlow", _in.tlow);
        console2.log("tcrit", _in.tcrit);
        console2.log("tMin", _in.tMin);
    }

    function _buildRandomUserFriendlyConfig(IDynamicKinkModel.UserFriendlyConfig memory _in) internal pure {
        _in.ulow = uint64(_in.ulow.randomBelow(0, DP - 4)); // -4 is to have space for other values, for every `<` we need to sub 1
        _in.u1 = uint64(_in.u1.randomInside(_in.ulow, DP - 3));
        _in.u2 = uint64(_in.u2.randomInside(_in.u1, DP - 2));
        _in.ucrit = uint64(_in.ucrit.randomInside(_in.u2, DP));

        // minimal values: 0 <= rmin < rcritMin < rritMax <= r100 --> 0 <= 0 < 1 < 2 <= r100
        _in.r100 = uint72(Math.max(2, _in.r100));
        _in.rmin = uint72(_in.rmin.randomBelow(0, _in.r100 - 1));
        _in.rcritMin = uint72(_in.rcritMin.randomInside(_in.rmin, _in.r100));
        _in.rcritMax = uint72(_in.rcritMax.randomAbove(_in.rcritMin, _in.r100));

        uint256 y = 365 days; // for purpose of fuzzing, 1y is a limit for time values
        uint256 d = 1 days;

        // 0 < tMin <= tcrit <= t2 < 100y  
        _in.tMin = uint32(_in.tMin.randomBetween(d, y));
        _in.tcrit = uint32(_in.tcrit.randomBetween(_in.tMin, y));
        _in.t2 = uint32(_in.t2.randomBetween(_in.tcrit, y));

        // 0 < tlow <= t1 < 100y
        _in.tlow = uint32(_in.tlow.randomBetween(d, y));
        _in.t1 = uint32(_in.t1.randomBetween(_in.tlow, y));
    }

    function _applyReasonableLimits(IDynamicKinkModel.UserFriendlyConfig memory _in) internal pure {
        _in.ulow = uint64(_in.ulow.randomBetween(0.01e18, 0.3e18)); // 1% - 30%
        _in.ucrit = uint64(_in.ucrit.randomBetween(0.7e18, 0.99e18)); // 70% - 99%

        _in.r100 = uint72(Math.max(0.5e18, 25 * DP));
        _in.rcritMin = uint72(_in.rcritMin.randomBetween(0.01e18, 0.5e18)); // 1% - 50% 

        _buildRandomUserFriendlyConfig(_in);
    }

    function _exampleOfUserFriendlyConfig_1() internal pure returns (IDynamicKinkModel.UserFriendlyConfig memory cfg) {
        cfg = IDynamicKinkModel.UserFriendlyConfig({
            ulow: 0.50e18,
            ucrit: 0.80e18,
            u1: 0.60e18,
            u2: 0.70e18,
            rmin: 0.005e18,
            rcritMin: 0.1e18,
            rcritMax: 0.8e18,
            r100: uint72(DP),
            t1: 3 days,
            t2: 3 days,
            tlow: 2 days,
            tcrit: 1 days,
            tMin: 1 hours
        });
    }
}
