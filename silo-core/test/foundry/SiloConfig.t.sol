// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloConfig, SiloConfig} from "silo-core/contracts/SiloConfig.sol";

/*
forge test -vv --mc SiloConfigTest
*/
contract SiloConfigTest is Test {
    address wrongSilo = address(10000000001);

    function siloConfigDeploy(
        uint256 _siloId,
        address _liquidator,
        ISiloConfig.ConfigData memory _configData0,
        ISiloConfig.ConfigData memory _configData1
    ) public returns (SiloConfig siloConfig) {
        vm.assume(_configData0.silo != wrongSilo);
        vm.assume(_configData1.silo != wrongSilo);
        vm.assume(_configData0.silo != _configData1.silo);

        _configData0.otherSilo = _configData1.silo;
        _configData1.otherSilo = _configData0.silo;
        _configData1.daoFee = _configData0.daoFee;
        _configData1.deployerFee = _configData0.deployerFee;

        siloConfig = new SiloConfig(_siloId, _liquidator, _configData0, _configData1);
    }

    /*
    forge test -vv --mt test_getSilos_fuzz
    */
    function test_getSilos_fuzz(
        uint256 _siloId,
        address _liquidator,
        ISiloConfig.ConfigData memory _configData0,
        ISiloConfig.ConfigData memory _configData1
    ) public {
        SiloConfig siloConfig = siloConfigDeploy(_siloId, _liquidator, _configData0, _configData1);

        (address silo0, address silo1) = siloConfig.getSilos();
        assertEq(silo0, _configData0.silo);
        assertEq(silo1, _configData1.silo);
    }

    /*
    forge test -vv --mt test_getShareTokens_fuzz
    */
    function test_getShareTokens_fuzz(
        uint256 _siloId,
        address _liquidator,
        ISiloConfig.ConfigData memory _configData0,
        ISiloConfig.ConfigData memory _configData1
    ) public {
        SiloConfig siloConfig = siloConfigDeploy(_siloId, _liquidator, _configData0, _configData1);

        vm.expectRevert(ISiloConfig.WrongSilo.selector);
        siloConfig.getShareTokens(wrongSilo);

        (address protectedShareToken, address collateralShareToken, address debtShareToken) = siloConfig.getShareTokens(_configData0.silo);
        assertEq(protectedShareToken, _configData0.protectedShareToken);
        assertEq(collateralShareToken, _configData0.collateralShareToken);
        assertEq(debtShareToken, _configData0.debtShareToken);

        (protectedShareToken, collateralShareToken, debtShareToken) = siloConfig.getShareTokens(_configData1.silo);
        assertEq(protectedShareToken, _configData1.protectedShareToken);
        assertEq(collateralShareToken, _configData1.collateralShareToken);
        assertEq(debtShareToken, _configData1.debtShareToken);
    }

    /*
    forge test -vv --mt test_getAssetForSilo_fuzz
    */
    function test_getAssetForSilo_fuzz(
        uint256 _siloId,
        address _liquidator,
        ISiloConfig.ConfigData memory _configData0,
        ISiloConfig.ConfigData memory _configData1
    ) public {
        SiloConfig siloConfig = siloConfigDeploy(_siloId, _liquidator, _configData0, _configData1);

        vm.expectRevert(ISiloConfig.WrongSilo.selector);
        siloConfig.getAssetForSilo(wrongSilo);

        assertEq(siloConfig.getAssetForSilo(_configData0.silo), _configData0.token);
        assertEq(siloConfig.getAssetForSilo(_configData1.silo), _configData1.token);
    }

    /*
    forge test -vv --mt test_getConfigs_fuzz
    */
    function test_getConfigs_fuzz(
        uint256 _siloId,
        address _liquidator,
        ISiloConfig.ConfigData memory _configData0,
        ISiloConfig.ConfigData memory _configData1
    ) public {
        SiloConfig siloConfig = siloConfigDeploy(_siloId, _liquidator, _configData0, _configData1);

        vm.expectRevert(ISiloConfig.WrongSilo.selector);
        siloConfig.getConfigs(wrongSilo);

        (ISiloConfig.ConfigData memory c0, ISiloConfig.ConfigData memory c1) = siloConfig.getConfigs(_configData0.silo);
        
        assertEq(keccak256(abi.encode(c0)), keccak256(abi.encode(_configData0)));
        assertEq(keccak256(abi.encode(c1)), keccak256(abi.encode(_configData1)));
    }

    /*
    forge test -vv --mt test_getConfig_fuzz
    */
    function test_getConfig_fuzz(
        uint256 _siloId,
        address _liquidator,
        ISiloConfig.ConfigData memory _configData0,
        ISiloConfig.ConfigData memory _configData1
    ) public {
        SiloConfig siloConfig = siloConfigDeploy(_siloId, _liquidator, _configData0, _configData1);

        vm.expectRevert(ISiloConfig.WrongSilo.selector);
        siloConfig.getConfig(wrongSilo);

        ISiloConfig.ConfigData memory c0 = siloConfig.getConfig(_configData0.silo);
        assertEq(keccak256(abi.encode(c0)), keccak256(abi.encode(_configData0)));

        ISiloConfig.ConfigData memory c1 = siloConfig.getConfig(_configData1.silo);
        assertEq(keccak256(abi.encode(c1)), keccak256(abi.encode(_configData1)));
    }

    /*
    forge test -vv --mt test_getFeesWithAsset_fuzz
    */
    function test_getFeesWithAsset_fuzz(
        uint256 _siloId,
        address _liquidator,
        ISiloConfig.ConfigData memory _configData0,
        ISiloConfig.ConfigData memory _configData1
    ) public {
        SiloConfig siloConfig = siloConfigDeploy(_siloId, _liquidator, _configData0, _configData1);

        vm.expectRevert(ISiloConfig.WrongSilo.selector);
        siloConfig.getFeesWithAsset(wrongSilo);

        (uint256 daoFee, uint256 deployerFee, uint256 flashloanFee, address asset) = siloConfig.getFeesWithAsset(_configData0.silo);
        
        assertEq(daoFee, _configData0.daoFee);
        assertEq(deployerFee, _configData0.deployerFee);
        assertEq(flashloanFee, _configData0.flashloanFee);
        assertEq(asset, _configData0.token);

        (daoFee, deployerFee, flashloanFee, asset) = siloConfig.getFeesWithAsset(_configData1.silo);
        
        assertEq(daoFee, _configData1.daoFee);
        assertEq(deployerFee, _configData1.deployerFee);
        assertEq(flashloanFee, _configData1.flashloanFee);
        assertEq(asset, _configData1.token);
    }
}
