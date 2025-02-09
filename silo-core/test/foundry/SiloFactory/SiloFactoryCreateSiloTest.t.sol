// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IInterestRateModelV2} from "silo-core/contracts/interfaces/IInterestRateModelV2.sol";
import {IInterestRateModelV2Config} from "silo-core/contracts/interfaces/IInterestRateModelV2Config.sol";
import {InterestRateModelV2} from "silo-core/contracts/interestRateModel/InterestRateModelV2.sol";

import {ISiloFactory} from "silo-core/contracts/SiloFactory.sol";
import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";
import {SiloConfigData} from "silo-core/deploy/input-readers/SiloConfigData.sol";
import {InterestRateModelConfigData} from "silo-core/deploy/input-readers/InterestRateModelConfigData.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {SiloLittleHelper} from "silo-core/test/foundry/_common/SiloLittleHelper.sol";

/*
forge test -vv --ffi --mc SiloFactoryCreateSiloTest
*/
contract SiloFactoryCreateSiloTest is SiloLittleHelper, IntegrationTest {
    string public constant SILO_TO_DEPLOY = SiloConfigsNames.SILO_LOCAL_NO_ORACLE_SILO;

    ISiloConfig siloConfig;
    SiloConfigData siloData;
    InterestRateModelConfigData modelData;

    event NewSilo(
        address indexed implementation,
        address indexed token0,
        address indexed token1,
        address silo0,
        address silo1,
        address siloConfig
    );

    function setUp() public {
        siloData = new SiloConfigData();
        modelData = new InterestRateModelConfigData();

        siloConfig = _setUpLocalFixture();

        siloFactory = ISiloFactory(getAddress(SiloCoreContracts.SILO_FACTORY));

        assertTrue(siloConfig.getConfig(address(silo0)).maxLtv != 0, "we need borrow to be allowed");
    }

    /*
    forge test -vv --ffi --mt test_createSilo
    */
    function test_createSilo() public {
        (, ISiloConfig.InitData memory initData,) = siloData.getConfigData(SILO_TO_DEPLOY);

        assertEq(siloFactory.getNextSiloId(), 2);
        assertTrue(siloFactory.isSilo(address(silo0)));
        assertTrue(siloFactory.isSilo(address(silo1)));

        address configFromFactory = siloFactory.idToSiloConfig(1);
        assertEq(configFromFactory, address(siloConfig));
        assertEq(configFromFactory, address(silo0.config()));
        assertEq(configFromFactory, address(silo1.config()));

        ISiloConfig.ConfigData memory configData0 = silo0.config().getConfig(address(silo0));
        ISiloConfig.ConfigData memory configData1 = silo0.config().getConfig(address(silo1));

        assertGe(configData0.daoFee, siloFactory.daoFeeRange().min, "configData0.daoFee.min");
        assertLe(configData0.daoFee, siloFactory.daoFeeRange().max, "configData0.daoFee.max");
        assertEq(configData0.deployerFee, initData.deployerFee, "configData0.deployerFee");
        // TODO check for both tokens
        // assertEq(configData0.token, initData.token0, "configData0.token");
        // assertEq(configData0.hookReceiver, initData.hookReceiver, "configData0.hookReceiver");
        assertTrue(configData0.silo != address(0), "configData0.silo");
        assertTrue(configData0.protectedShareToken != address(0), "configData0.protectedShareToken");
        assertTrue(configData0.collateralShareToken != address(0), "configData0.collateralShareToken");
        assertTrue(configData0.debtShareToken != address(0), "configData0.debtShareToken");
        assertEq(configData0.solvencyOracle, initData.solvencyOracle0, "configData0.solvencyOracle");
        assertEq(configData0.maxLtvOracle, initData.maxLtvOracle0, "configData0.maxLtvOracle");
        assertEq(configData0.maxLtv, initData.maxLtv0, "configData0.maxLtv");
        assertEq(configData0.lt, initData.lt0, "configData0.lt");
        assertEq(configData0.liquidationFee, initData.liquidationFee0, "configData0.liquidationFee");
        assertEq(configData0.flashloanFee, initData.flashloanFee0, "configData0.flashloanFee");
        assertEq(configData0.callBeforeQuote, initData.callBeforeQuote0, "configData0.callBeforeQuote");

        assertGe(configData1.daoFee, siloFactory.daoFeeRange().min, "configData1.daoFee.min");
        assertLe(configData1.daoFee, siloFactory.daoFeeRange().max, "configData1.daoFee.max");
        assertEq(configData1.deployerFee, initData.deployerFee, "configData1.deployerFee");
        assertTrue(configData1.silo != address(0), "configData1.silo");
        assertTrue(configData1.protectedShareToken != address(0), "configData1.protectedShareToken");
        assertTrue(configData1.collateralShareToken != address(0), "configData1.collateralShareToken");
        assertTrue(configData1.debtShareToken != address(0), "configData1.debtShareToken");
        assertEq(configData1.solvencyOracle, initData.solvencyOracle1, "configData1.solvencyOracle");
        assertEq(configData1.maxLtvOracle, initData.maxLtvOracle1, "configData1.maxLtvOracle");
        assertEq(configData1.maxLtv, initData.maxLtv1, "configData1.maxLtv");
        assertEq(configData1.lt, initData.lt1, "configData1.lt");
        assertEq(configData1.liquidationFee, initData.liquidationFee1, "configData1.liquidationFee");
        assertEq(configData1.flashloanFee, initData.flashloanFee1, "configData1.flashloanFee");
        assertEq(configData1.callBeforeQuote, initData.callBeforeQuote1, "configData1.callBeforeQuote");

        vm.expectRevert(ISilo.SiloInitialized.selector);
        ISilo(configData0.silo).initialize(siloConfig);

        vm.expectRevert(ISilo.SiloInitialized.selector);
        ISilo(configData1.silo).initialize(siloConfig);

        IInterestRateModelV2Config modelConfigAddr0 = InterestRateModelV2(configData0.interestRateModel).irmConfig();
        IInterestRateModelV2.Config memory irmConfigUsed0 = modelConfigAddr0.getConfig();

        (SiloConfigData.ConfigData memory siloConfigData,,) = siloData.getConfigData(SILO_TO_DEPLOY);
        IInterestRateModelV2.Config memory irmConfigExpected0 =
            modelData.getConfigData(siloConfigData.interestRateModelConfig0);

        assertEq(abi.encode(irmConfigUsed0), abi.encode(irmConfigExpected0));

        IInterestRateModelV2Config modelConfigAddr1 = InterestRateModelV2(configData1.interestRateModel).irmConfig();
        IInterestRateModelV2.Config memory irmConfigUsed1 = modelConfigAddr1.getConfig();

        IInterestRateModelV2.Config memory irmConfigExpected1 =
            modelData.getConfigData(siloConfigData.interestRateModelConfig1);

        assertEq(abi.encode(irmConfigUsed1), abi.encode(irmConfigExpected1));

        assertEq(siloFactory.ownerOf(1), initData.deployer);
    }

    /*
    forge test -vv --ffi --mt test_createSilo_zeroes
    */
    function test_createSilo_zeroes() public {
        (, ISiloConfig.InitData memory initData,) = siloData.getConfigData(SILO_TO_DEPLOY);

        address siloImpl = makeAddr("siloImpl");
        address shareProtectedCollateralTokenImpl = makeAddr("shareProtectedCollateralTokenImpl");
        address shareDebtTokenImpl = makeAddr("shareDebtTokenImpl");
        ISiloConfig config = ISiloConfig(makeAddr("siloConfig"));

        vm.expectRevert(ISiloFactory.ZeroAddress.selector); // silo config empty
        siloFactory.createSilo(
            initData, ISiloConfig(address(0)), siloImpl, shareProtectedCollateralTokenImpl, shareDebtTokenImpl
        );

        vm.expectRevert(ISiloFactory.ZeroAddress.selector); // silo impl empty
        siloFactory.createSilo(initData, config, address(0), shareProtectedCollateralTokenImpl, shareDebtTokenImpl);

        vm.expectRevert(ISiloFactory.ZeroAddress.selector); // shareProtectedCollateralTokenImpl empty
        siloFactory.createSilo(initData, config, siloImpl, address(0), shareDebtTokenImpl);

        vm.expectRevert(ISiloFactory.ZeroAddress.selector); // shareDebtTokenImpl empty
        siloFactory.createSilo(initData, config, siloImpl, shareProtectedCollateralTokenImpl, address(0));
    }

    /*
    forge test -vv --ffi --mt test_createSilo_NewSiloEvent
    */
    function test_createSilo_NewSiloEvent() public {
        (, ISiloConfig.InitData memory initData,) = siloData.getConfigData(SILO_TO_DEPLOY);

        address siloImpl = makeAddr("siloImpl");
        address shareProtectedCollateralTokenImpl = makeAddr("shareProtectedCollateralTokenImpl");
        address shareDebtTokenImpl = makeAddr("shareDebtTokenImpl");

        ISiloConfig config = ISiloConfig(makeAddr("siloConfig"));

        initData.hookReceiver = makeAddr("hookReceiver");
        initData.token0 = makeAddr("token0");
        initData.token1 = makeAddr("token1");
        
        vm.expectEmit(true, true, true, false);

        emit NewSilo(
            makeAddr("siloImpl"),
            makeAddr("token0"),
            makeAddr("token1"),
            address(0),
            address(0),
            makeAddr("siloConfig")
        );

        siloFactory.createSilo(initData, config, siloImpl, shareProtectedCollateralTokenImpl, shareDebtTokenImpl);
    }
}
