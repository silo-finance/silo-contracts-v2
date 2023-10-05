// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISiloFactory, SiloFactory} from "silo-core/contracts/SiloFactory.sol";
import {SiloFactoryDeploy} from "silo-core/deploy/SiloFactoryDeploy.s.sol";

/*
forge test -vv --mc SiloFactoryValidateSiloInitDataTest
*/
contract SiloFactoryValidateSiloInitDataTest is Test {
    uint256 internal constant _BASIS_POINTS = 1e4;

    ISiloFactory public siloFactory;

    function setUp() public {
        SiloFactoryDeploy siloFactoryDeploy = new SiloFactoryDeploy();
        siloFactoryDeploy.disableDeploymentsSync();
        siloFactory = siloFactoryDeploy.run();
    }

    /*
    forge test -vv --mt test_validateSiloInitData
    */
    function test_validateSiloInitData() public {
        ISiloConfig.InitData memory initData;

        vm.expectRevert(ISiloFactory.SameAsset.selector);
        siloFactory.validateSiloInitData(initData);

        initData.token0 = address(1);
        initData.token1 = address(2);

        vm.expectRevert(ISiloFactory.InvalidMaxLtv.selector);
        siloFactory.validateSiloInitData(initData);

        initData.maxLtv0 = 7500;
        initData.maxLtv1 = 6500;

        vm.expectRevert(ISiloFactory.InvalidMaxLtv.selector);
        siloFactory.validateSiloInitData(initData);

        initData.lt0 = 85000;
        initData.lt1 = 75000;

        vm.expectRevert(ISiloFactory.InvalidLt.selector);
        siloFactory.validateSiloInitData(initData);

        initData.lt0 = 8500;
        initData.lt1 = 7500;

        vm.expectRevert(ISiloFactory.NonBorrowableSilo.selector);
        siloFactory.validateSiloInitData(initData);

        initData.borrowable0 = true;
        initData.borrowable1 = true;

        vm.expectRevert(ISiloFactory.InvalidIrmConfig.selector);
        siloFactory.validateSiloInitData(initData);

        initData.deployerFeeInBp = 100;

        vm.expectRevert(ISiloFactory.InvalidDeployer.selector);
        siloFactory.validateSiloInitData(initData);

        initData.deployer = address(100001);

        vm.expectRevert(ISiloFactory.InvalidIrmConfig.selector);
        siloFactory.validateSiloInitData(initData);

        initData.deployerFeeInBp = siloFactory.maxDeployerFeeInBp() + 1;

        vm.expectRevert(ISiloFactory.MaxDeployerFee.selector);
        siloFactory.validateSiloInitData(initData);

        initData.deployerFeeInBp = 0.01e4;

        vm.expectRevert(ISiloFactory.InvalidIrmConfig.selector);
        siloFactory.validateSiloInitData(initData);

        initData.flashloanFee0 = uint64(siloFactory.maxFlashloanFeeInBp() + 1);

        vm.expectRevert(ISiloFactory.MaxFlashloanFee.selector);
        siloFactory.validateSiloInitData(initData);

        initData.flashloanFee0 = 0.01e4;

        vm.expectRevert(ISiloFactory.InvalidIrmConfig.selector);
        siloFactory.validateSiloInitData(initData);

        initData.flashloanFee1 = uint64(siloFactory.maxFlashloanFeeInBp() + 1);

        vm.expectRevert(ISiloFactory.MaxFlashloanFee.selector);
        siloFactory.validateSiloInitData(initData);

        initData.flashloanFee1 = 0.01e4;

        vm.expectRevert(ISiloFactory.InvalidIrmConfig.selector);
        siloFactory.validateSiloInitData(initData);

        initData.liquidationFee0 = uint64(siloFactory.maxLiquidationFeeInBp() + 1);

        vm.expectRevert(ISiloFactory.MaxLiquidationFee.selector);
        siloFactory.validateSiloInitData(initData);

        initData.liquidationFee0 = 0.01e4;

        vm.expectRevert(ISiloFactory.InvalidIrmConfig.selector);
        siloFactory.validateSiloInitData(initData);

        initData.liquidationFee1 = uint64(siloFactory.maxLiquidationFeeInBp() + 1);

        vm.expectRevert(ISiloFactory.MaxLiquidationFee.selector);
        siloFactory.validateSiloInitData(initData);

        initData.liquidationFee1 = 0.01e4;

        vm.expectRevert(ISiloFactory.InvalidIrmConfig.selector);
        siloFactory.validateSiloInitData(initData);

        initData.interestRateModelConfig0 = address(100005);

        vm.expectRevert(ISiloFactory.InvalidIrmConfig.selector);
        siloFactory.validateSiloInitData(initData);

        initData.interestRateModelConfig1 = initData.interestRateModelConfig0;

        vm.expectRevert(ISiloFactory.InvalidIrm.selector);
        siloFactory.validateSiloInitData(initData);

        initData.interestRateModel0 = address(100006);

        vm.expectRevert(ISiloFactory.InvalidIrm.selector);
        siloFactory.validateSiloInitData(initData);

        initData.interestRateModel1 = initData.interestRateModel0;

        assertTrue(siloFactory.validateSiloInitData(initData));
    }
}
