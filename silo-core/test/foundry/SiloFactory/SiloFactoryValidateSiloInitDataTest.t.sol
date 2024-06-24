// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISiloFactory, SiloFactory} from "silo-core/contracts/SiloFactory.sol";
import {SiloFactoryDeploy} from "silo-core/deploy/SiloFactoryDeploy.s.sol";

/*
forge test -vv --mc SiloFactoryValidateSiloInitDataTest
*/
contract SiloFactoryValidateSiloInitDataTest is Test {
    ISiloFactory public siloFactory;

    address internal _timelock = makeAddr("Timelock");
    address internal _feeDistributor = makeAddr("FeeDistributor");

    function setUp() public {
        // Mock addresses that we need for the `SiloFactoryDeploy` script
        AddrLib.setAddress(VeSiloContracts.TIMELOCK_CONTROLLER, _timelock);
        AddrLib.setAddress(VeSiloContracts.FEE_DISTRIBUTOR, _feeDistributor);

        SiloFactoryDeploy siloFactoryDeploy = new SiloFactoryDeploy();
        siloFactoryDeploy.disableDeploymentsSync();
        siloFactory = siloFactoryDeploy.run();
    }

    /*
    forge test -vv --mt test_validateSiloInitData
    */
    function test_validateSiloInitData() public {
        ISiloConfig.InitData memory initData;

        vm.expectRevert(ISiloFactory.MissingHookReceiver.selector);
        siloFactory.validateSiloInitData(initData);
        initData.hookReceiver = address(2);

        vm.expectRevert(ISiloFactory.EmptyToken0.selector);
        siloFactory.validateSiloInitData(initData);
        initData.token0 = address(1);

        vm.expectRevert(ISiloFactory.EmptyToken1.selector); // even when zeros
        siloFactory.validateSiloInitData(initData);
        initData.token1 = address(1);

        vm.expectRevert(ISiloFactory.SameAsset.selector); // even when zeros
        siloFactory.validateSiloInitData(initData);

        initData.token1 = address(2);

        vm.expectRevert(ISiloFactory.InvalidMaxLtv.selector);
        siloFactory.validateSiloInitData(initData);

        initData.maxLtv0 = 0.75e18;
        initData.maxLtv1 = 0.65e18;

        vm.expectRevert(ISiloFactory.InvalidMaxLtv.selector);
        siloFactory.validateSiloInitData(initData);

        initData.lt0 = 8.50e18;
        initData.lt1 = 7.50e18;

        vm.expectRevert(ISiloFactory.InvalidLt.selector);
        siloFactory.validateSiloInitData(initData);

        initData.lt0 = 0.85e18;
        initData.lt1 = 0.75e18;

        vm.expectRevert(ISiloFactory.InvalidIrmConfig.selector);
        siloFactory.validateSiloInitData(initData);

        initData.maxLtvOracle0 = address(1);
        vm.expectRevert(ISiloFactory.OracleMisconfiguration.selector);
        siloFactory.validateSiloInitData(initData);

        initData.callBeforeQuote0 = true;
        initData.maxLtvOracle0 = address(0);
        initData.solvencyOracle0 = address(0);
        vm.expectRevert(ISiloFactory.BeforeCall.selector);
        siloFactory.validateSiloInitData(initData);

        initData.solvencyOracle0 = address(1);

        initData.maxLtvOracle1 = address(1);
        vm.expectRevert(ISiloFactory.OracleMisconfiguration.selector);
        siloFactory.validateSiloInitData(initData);

        initData.callBeforeQuote1 = true;
        initData.maxLtvOracle1 = address(0);
        vm.expectRevert(ISiloFactory.BeforeCall.selector);
        siloFactory.validateSiloInitData(initData);

        initData.solvencyOracle1 = address(1);

        initData.deployerFee = 0.01e18;

        vm.expectRevert(ISiloFactory.InvalidDeployer.selector);
        siloFactory.validateSiloInitData(initData);

        initData.deployer = address(100001);

        vm.expectRevert(ISiloFactory.InvalidIrmConfig.selector);
        siloFactory.validateSiloInitData(initData);

        initData.deployerFee = siloFactory.maxDeployerFee() + 1;

        vm.expectRevert(ISiloFactory.MaxDeployerFee.selector);
        siloFactory.validateSiloInitData(initData);

        initData.deployerFee = 0.01e18;

        vm.expectRevert(ISiloFactory.InvalidIrmConfig.selector);
        siloFactory.validateSiloInitData(initData);

        initData.flashloanFee0 = uint64(siloFactory.maxFlashloanFee() + 1);

        vm.expectRevert(ISiloFactory.MaxFlashloanFee.selector);
        siloFactory.validateSiloInitData(initData);

        initData.flashloanFee0 = 0.01e18;

        vm.expectRevert(ISiloFactory.InvalidIrmConfig.selector);
        siloFactory.validateSiloInitData(initData);

        initData.flashloanFee1 = uint64(siloFactory.maxFlashloanFee() + 1);

        vm.expectRevert(ISiloFactory.MaxFlashloanFee.selector);
        siloFactory.validateSiloInitData(initData);

        initData.flashloanFee1 = 0.01e18;

        vm.expectRevert(ISiloFactory.InvalidIrmConfig.selector);
        siloFactory.validateSiloInitData(initData);

        initData.liquidationFee0 = uint64(siloFactory.maxLiquidationFee() + 1);

        vm.expectRevert(ISiloFactory.MaxLiquidationFee.selector);
        siloFactory.validateSiloInitData(initData);

        initData.liquidationFee0 = 0.01e18;

        vm.expectRevert(ISiloFactory.InvalidIrmConfig.selector);
        siloFactory.validateSiloInitData(initData);

        initData.liquidationFee1 = uint64(siloFactory.maxLiquidationFee() + 1);

        vm.expectRevert(ISiloFactory.MaxLiquidationFee.selector);
        siloFactory.validateSiloInitData(initData);

        initData.liquidationFee1 = 0.01e18;

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
