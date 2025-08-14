// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {Ownable} from "openzeppelin5/access/Ownable.sol";

import {DynamicKinkModel, IDynamicKinkModel} from "../../../../contracts/interestRateModel/kink/DynamicKinkModel.sol";
import {IDynamicKinkModelConfig} from "../../../../contracts/interestRateModel/kink/DynamicKinkModelConfig.sol";
import {DynamicKinkModelFactory} from "../../../../contracts/interestRateModel/kink/DynamicKinkModelFactory.sol";
import {IDynamicKinkModelFactory} from "../../../../contracts/interfaces/IDynamicKinkModelFactory.sol";
import {IInterestRateModel} from "../../../../contracts/interfaces/IInterestRateModel.sol";

import {ISilo} from "../../../../contracts/interfaces/ISilo.sol";
import {KinkCommon} from "./KinkCommon.sol";

/* 
FOUNDRY_PROFILE=core_test forge test --mc DynamicKinkModelFactoryTest -vv
*/
contract DynamicKinkModelFactoryTest is KinkCommon {
    DynamicKinkModelFactory immutable FACTORY = new DynamicKinkModelFactory();

    function setUp() public {
        IDynamicKinkModel.Config memory emptyConfig;
        irm = DynamicKinkModel(address(FACTORY.create(emptyConfig, address(this), address(this), bytes32(0))));
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_create_revertOnInvalidConfig -vv
    */
    function test_create_revertOnInvalidConfig(IDynamicKinkModel.Config memory _config) public {
        vm.assume(!_isValidConfig(_config));

        vm.expectRevert();
        FACTORY.create(_config, address(this), address(this), bytes32(0));
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mt test_predictAddress_pass -vv
    */
    function test_predictAddress_pass(
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
    function test_create_pass(RandomKinkConfig memory _config) public whenValidConfig(_config) {
        address predictedAddress = FACTORY.predictAddress(address(this), bytes32(0));   

        vm.expectEmit(true, true, true, true);
        emit IDynamicKinkModelFactory.NewDynamicKinkModel(IDynamicKinkModel(predictedAddress));

        FACTORY.create(_toConfig(_config), address(this), address(this), bytes32(0));

        assertTrue(FACTORY.createdByFactory(predictedAddress));
    }
}
