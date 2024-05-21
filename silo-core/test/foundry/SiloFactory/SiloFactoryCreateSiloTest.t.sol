// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IInterestRateModelV2} from "silo-core/contracts/interfaces/IInterestRateModelV2.sol";
import {IInterestRateModelV2Config} from "silo-core/contracts/interfaces/IInterestRateModelV2Config.sol";
import {InterestRateModelV2} from "silo-core/contracts/interestRateModel/InterestRateModelV2.sol";

import {SiloFactory, ISiloFactory} from "silo-core/contracts/SiloFactory.sol";
import {MainnetDeploy} from "silo-core/deploy/MainnetDeploy.s.sol";
import {MintableToken} from "silo-core/test/foundry/_common/MintableToken.sol";
import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";
import {SiloConfigData} from "silo-core/deploy/input-readers/SiloConfigData.sol";
import {InterestRateModelConfigData} from "silo-core/deploy/input-readers/InterestRateModelConfigData.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {SiloFixture} from "silo-core/test/foundry/_common/fixtures/SiloFixture.sol";
import {SiloLittleHelper} from "silo-core/test/foundry/_common/SiloLittleHelper.sol";

/*
forge test -vv --ffi --mc SiloFactoryCreateSiloTest
*/
contract SiloFactoryCreateSiloTest is SiloLittleHelper, IntegrationTest {
    string public constant SILO_TO_DEPLOY = SiloConfigsNames.ETH_USDC_UNI_V3_SILO;

    ISiloFactory siloFactory;
    ISiloConfig siloConfig;
    SiloConfigData siloData;
    InterestRateModelConfigData modelData;

    function setUp() public {
        siloData = new SiloConfigData();
        modelData = new InterestRateModelConfigData();

        siloConfig = _setUpLocalFixture();

        siloFactory = ISiloFactory(getAddress(SiloCoreContracts.SILO_FACTORY));

        assertTrue(siloConfig.getConfig(address(silo0)).maxLtv != 0, "we need borrow to be allowed");
    }

    /*
    forge test -vv --ffi --mt test_failToCreateSiloWhenUninitialized
    */
    function test_failToCreateSiloWhenUninitialized() public {
        SiloFactory siloFactoryTest = new SiloFactory();

        // ensure that the factory is uninitialized
        assertEq(siloFactoryTest.getNextSiloId(), 0);

        (, ISiloConfig.InitData memory initData,) = siloData.getConfigData(SILO_TO_DEPLOY);

        initData.token0 = makeAddr("token0");
        initData.token1 = makeAddr("token1");
        initData.deployerFee = 0;
        initData.flashloanFee0 = 0;
        initData.flashloanFee1 = 0;
        initData.liquidationFee0 = 0;
        initData.liquidationFee1 = 0;
        initData.interestRateModelConfig0 = makeAddr("irmConfig0");
        initData.interestRateModelConfig1 = makeAddr("irmConfig1");
        initData.interestRateModel0 = makeAddr("irm0");
        initData.interestRateModel1 = makeAddr("irm1");

        vm.expectRevert(ISiloFactory.Uninitialized.selector);
        siloFactoryTest.createSilo(initData);
    }

    /*
    forge test -vv --ffi --mt test_createSilo
    */
    function test_createSilo() public {
        (, ISiloConfig.InitData memory initData,) = siloData.getConfigData(SILO_TO_DEPLOY);

        assertEq(siloFactory.getNextSiloId(), 2);
        assertTrue(siloFactory.isSilo(address(silo0)));
        assertTrue(siloFactory.isSilo(address(silo1)));

        address[2] memory silos = siloFactory.idToSilos(1);
        assertEq(silos[0], address(silo0));
        assertEq(silos[1], address(silo1));

        (
            ISiloConfig.ConfigData memory configData0,
            ISiloConfig.ConfigData memory configData1,
        ) = siloConfig.getConfigs(address(silo0), address(0), 0 /* always 0 for external calls */);

        assertEq(configData0.daoFee, siloFactory.daoFee(), "configData0.daoFee");
        assertEq(configData0.deployerFee, initData.deployerFee, "configData0.deployerFee");
        assertEq(configData0.silo, configData1.otherSilo, "configData0.silo");
        assertEq(configData0.otherSilo, configData1.silo, "configData0.otherSilo");
        assertTrue(configData0.silo != address(0), "configData0.silo");
        assertTrue(configData0.otherSilo != address(0), "configData0.otherSilo");
        assertTrue(configData0.protectedShareToken != address(0), "configData0.protectedShareToken");
        assertTrue(configData0.collateralShareToken != address(0), "configData0.collateralShareToken");
        assertTrue(configData0.debtShareToken != address(0), "configData0.debtShareToken");
        assertEq(configData0.solvencyOracle, initData.solvencyOracle0, "configData0.solvencyOracle");
        assertEq(configData0.maxLtvOracle, initData.maxLtvOracle0, "configData0.maxLtvOracle");
        assertEq(configData0.interestRateModel, getAddress(SiloCoreContracts.INTEREST_RATE_MODEL_V2));
        assertEq(configData0.maxLtv, initData.maxLtv0, "configData0.maxLtv");
        assertEq(configData0.lt, initData.lt0, "configData0.lt");
        assertEq(configData0.liquidationFee, initData.liquidationFee0, "configData0.liquidationFee");
        assertEq(configData0.flashloanFee, initData.flashloanFee0, "configData0.flashloanFee");
        assertEq(configData0.callBeforeQuote, initData.callBeforeQuote0, "configData0.callBeforeQuote");

        assertEq(configData1.daoFee, siloFactory.daoFee(), "configData1.daoFee");
        assertEq(configData1.deployerFee, initData.deployerFee, "configData1.deployerFee");
        assertEq(configData1.silo, configData0.otherSilo, "configData1.silo");
        assertEq(configData1.otherSilo, configData0.silo, "configData1.otherSilo");
        assertTrue(configData1.silo != address(0), "configData1.silo");
        assertTrue(configData1.otherSilo != address(0), "configData1.otherSilo");
        assertTrue(configData1.protectedShareToken != address(0), "configData1.protectedShareToken");
        assertTrue(configData1.collateralShareToken != address(0), "configData1.collateralShareToken");
        assertTrue(configData1.debtShareToken != address(0), "configData1.debtShareToken");
        assertEq(configData1.solvencyOracle, initData.solvencyOracle1, "configData1.solvencyOracle");
        assertEq(configData1.maxLtvOracle, initData.maxLtvOracle1, "configData1.maxLtvOracle");
        assertEq(configData1.interestRateModel, getAddress(SiloCoreContracts.INTEREST_RATE_MODEL_V2));
        assertEq(configData1.maxLtv, initData.maxLtv1, "configData1.maxLtv");
        assertEq(configData1.lt, initData.lt1, "configData1.lt");
        assertEq(configData1.liquidationFee, initData.liquidationFee1, "configData1.liquidationFee");
        assertEq(configData1.flashloanFee, initData.flashloanFee1, "configData1.flashloanFee");
        assertEq(configData1.callBeforeQuote, initData.callBeforeQuote1, "configData1.callBeforeQuote");

        vm.expectRevert(ISilo.SiloInitialized.selector);
        ISilo(configData0.silo).initialize(siloConfig, initData.interestRateModelConfig0);

        vm.expectRevert(ISilo.SiloInitialized.selector);
        ISilo(configData1.silo).initialize(siloConfig, initData.interestRateModelConfig1);

        (,, IInterestRateModelV2Config modelConfigAddr0) =
            InterestRateModelV2(configData0.interestRateModel).getSetup(configData0.silo);
        IInterestRateModelV2.Config memory irmConfigUsed0 = modelConfigAddr0.getConfig();

        (SiloConfigData.ConfigData memory siloConfigData,,) = siloData.getConfigData(SILO_TO_DEPLOY);
        IInterestRateModelV2.Config memory irmConfigExpected0 =
            modelData.getConfigData(siloConfigData.interestRateModelConfig0);

        assertEq(abi.encode(irmConfigUsed0), abi.encode(irmConfigExpected0));

        (,, IInterestRateModelV2Config modelConfigAddr1) =
            InterestRateModelV2(configData1.interestRateModel).getSetup(configData1.silo);
        IInterestRateModelV2.Config memory irmConfigUsed1 = modelConfigAddr1.getConfig();

        IInterestRateModelV2.Config memory irmConfigExpected1 =
            modelData.getConfigData(siloConfigData.interestRateModelConfig1);

        assertEq(abi.encode(irmConfigUsed1), abi.encode(irmConfigExpected1));

        vm.expectRevert(ISiloFactory.InvalidInitialization.selector);
        IShareToken(configData0.protectedShareToken).initialize(ISilo(configData0.silo), address(0), 0);

        vm.expectRevert(ISiloFactory.InvalidInitialization.selector);
        IShareToken(configData0.collateralShareToken).initialize(ISilo(configData0.silo), address(0), 0);

        vm.expectRevert(ISiloFactory.InvalidInitialization.selector);
        IShareToken(configData0.debtShareToken).initialize(ISilo(configData0.silo), address(0), 0);

        vm.expectRevert(ISiloFactory.InvalidInitialization.selector);
        IShareToken(configData1.protectedShareToken).initialize(ISilo(configData1.silo), address(0), 0);

        vm.expectRevert(ISiloFactory.InvalidInitialization.selector);
        IShareToken(configData1.collateralShareToken).initialize(ISilo(configData1.silo), address(0), 0);

        vm.expectRevert(ISiloFactory.InvalidInitialization.selector);
        IShareToken(configData1.debtShareToken).initialize(ISilo(configData1.silo), address(0), 0);

        assertEq(siloFactory.ownerOf(1), initData.deployer);
    }
}
