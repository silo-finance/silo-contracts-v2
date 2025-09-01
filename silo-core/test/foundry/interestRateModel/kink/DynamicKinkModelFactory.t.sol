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
import {KinkCommonTest} from "./KinkCommon.t.sol";

import {RandomLib} from "../../_common/RandomLib.sol";

contract DynamicKinkFactoryMock is DynamicKinkModelFactory {
    function castConfig(IDynamicKinkModel.UserFriendlyConfig calldata _default)
        external
        pure
        returns (IDynamicKinkModel.UserFriendlyConfigInt memory)
    {
        return _castConfig(_default);
    }
}

/* 
FOUNDRY_PROFILE=core_test forge test --mc DynamicKinkModelFactoryTest -vv
*/
contract DynamicKinkModelFactoryTest is KinkCommonTest {
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
    function test_kink_predictAddress_pass(RandomKinkConfig memory _config, address _deployer, bytes32 _externalSalt)
        public
        whenValidConfig(_config)
    {
        vm.assume(_deployer != address(0));

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
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_generateConfig_alwaysWorks -vv
    */
    /// forge-config: core_test.fuzz.runs = 1000
    function test_kink_generateConfig_alwaysWorks_fuzz(IDynamicKinkModel.UserFriendlyConfig memory _in) public {
        // _printUserFriendlyConfig(_in);

        // start help fuzzing ----------------------------
        // with straight config as input, we fail with too many rejection,
        // so we need to "help" to build config that will pass
        _buildRandomUserFriendlyConfig(_in);
        // end help fuzzing ------------------------------

        // _printUserFriendlyConfig(_in);

        try FACTORY.generateConfig(_in) returns (IDynamicKinkModel.Config memory config) {
            // any config can be used to create IRM
            FACTORY.create(config, address(this), address(this), bytes32(0));
        } catch (bytes memory revertData) {
            bytes32 revertHash = keccak256(revertData);
            vm.assume(false);
        }
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_kink_castConfig -vv
    */
    function test_kink_castConfig(IDynamicKinkModel.UserFriendlyConfig memory _in) public {
        DynamicKinkFactoryMock factory = new DynamicKinkFactoryMock();

        IDynamicKinkModel.UserFriendlyConfigInt memory _out = factory.castConfig(_in);

        bytes32 hashIn = keccak256(abi.encode(_in));
        bytes32 hashOut = keccak256(abi.encode(_out));

        assertEq(hashIn, hashOut, "castConfig fail In != Out");
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
}
