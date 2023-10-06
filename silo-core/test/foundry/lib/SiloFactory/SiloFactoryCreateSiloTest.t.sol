// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IInterestRateModelV2} from "silo-core/contracts/interfaces/IInterestRateModelV2.sol";
import {IInterestRateModelV2Config} from "silo-core/contracts/interfaces/IInterestRateModelV2Config.sol";
import {InterestRateModelV2} from "silo-core/contracts/interestRateModel/InterestRateModelV2.sol";

import {ISiloFactory} from "silo-core/contracts/SiloFactory.sol";
import {MainnetDeploy} from "silo-core/deploy/MainnetDeploy.s.sol";
import {MintableToken} from "silo-core/test/foundry/_common/MintableToken.sol";
import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";
import {SiloConfigData} from "silo-core/deploy/input-readers/SiloConfigData.sol";
import {InterestRateModelConfigData} from "silo-core/deploy/input-readers/InterestRateModelConfigData.sol";

import {SiloFixture} from "silo-core/test/foundry/_common/fixtures/SiloFixture.sol";
import {SiloLittleHelper} from "silo-core/test/foundry/_common/SiloLittleHelper.sol";

/*
forge test -vv --mc SiloFactoryCreateSiloTest
*/
contract SiloFactoryCreateSiloTest is SiloLittleHelper, IntegrationTest {
    uint256 internal constant _BASIS_POINTS = 1e4;

    string public constant SILO_TO_DEPLOY = "ETH-USDC_UniswapV3_Silo";

    ISiloFactory siloFactory;
    ISiloConfig siloConfig;
    SiloConfigData siloData;
    InterestRateModelConfigData modelData;

    function setUp() public {
        siloData = new SiloConfigData();
        modelData = new InterestRateModelConfigData();

        token0 = new MintableToken();
        token1 = new MintableToken();

        SiloFixture siloFixture = new SiloFixture();
        (siloConfig, silo0, silo1,,) = siloFixture.deploy_local(SiloFixture.Override(address(token0), address(token1)));

        __init(vm, token0, token1, silo0, silo1);

        siloFactory = ISiloFactory(getAddress(SiloCoreContracts.SILO_FACTORY));

        assertTrue(siloConfig.getConfig(address(silo0)).borrowable, "we need borrow to be allowed");
    }

    /*
    forge test -vv --mt test_createSilo
    */
    function test_createSilo() public {
        (SiloConfigData.ConfigData memory config, ISiloConfig.InitData memory initData) =
            siloData.getConfigData(SILO_TO_DEPLOY);

        assertEq(siloFactory.getNextSiloId(), 2);
        assertTrue(siloFactory.isSilo(address(silo0)));
        assertTrue(siloFactory.isSilo(address(silo1)));

        address[2] memory silos = siloFactory.idToSilos(1);
        assertEq(silos[0], address(silo0));
        assertEq(silos[1], address(silo1));

        (ISiloConfig.ConfigData memory configData0, ISiloConfig.ConfigData memory configData1) =
            siloConfig.getConfigs(address(silo0));
        assertEq(configData0.daoFeeInBp, siloFactory.daoFeeInBp());
        assertEq(configData0.deployerFeeInBp, initData.deployerFeeInBp);
        assertEq(configData0.silo, configData1.otherSilo);
        assertEq(configData0.otherSilo, configData1.silo);
        assertTrue(configData0.silo != address(0));
        assertTrue(configData0.otherSilo != address(0));
        assertTrue(configData0.protectedShareToken != address(0));
        assertTrue(configData0.collateralShareToken != address(0));
        assertTrue(configData0.debtShareToken != address(0));
        assertEq(configData0.solvencyOracle, initData.solvencyOracle0);
        assertEq(configData0.maxLtvOracle, initData.maxLtvOracle0);
        assertEq(configData0.interestRateModel, getAddress(SiloCoreContracts.INTEREST_RATE_MODEL_V2));
        assertEq(configData0.maxLtv, initData.maxLtv0);
        assertEq(configData0.lt, initData.lt0);
        assertEq(configData0.liquidationFee, initData.liquidationFee0);
        assertEq(configData0.flashloanFee, initData.flashloanFee0);
        assertEq(configData0.borrowable, initData.borrowable0);

        assertEq(configData1.daoFeeInBp, siloFactory.daoFeeInBp());
        assertEq(configData1.deployerFeeInBp, initData.deployerFeeInBp);
        assertEq(configData1.silo, configData0.otherSilo);
        assertEq(configData1.otherSilo, configData0.silo);
        assertTrue(configData1.silo != address(0));
        assertTrue(configData1.otherSilo != address(0));
        assertTrue(configData1.protectedShareToken != address(0));
        assertTrue(configData1.collateralShareToken != address(0));
        assertTrue(configData1.debtShareToken != address(0));
        assertEq(configData1.solvencyOracle, initData.solvencyOracle1);
        assertEq(configData1.maxLtvOracle, initData.maxLtvOracle1);
        assertEq(configData1.interestRateModel, getAddress(SiloCoreContracts.INTEREST_RATE_MODEL_V2));
        assertEq(configData1.maxLtv, initData.maxLtv1);
        assertEq(configData1.lt, initData.lt1);
        assertEq(configData1.liquidationFee, initData.liquidationFee1);
        assertEq(configData1.flashloanFee, initData.flashloanFee1);
        assertEq(configData1.borrowable, initData.borrowable1);

        vm.expectRevert("Initializable: contract is already initialized");
        ISilo(configData0.silo).initialize(siloConfig, initData.interestRateModelConfig0);

        vm.expectRevert("Initializable: contract is already initialized");
        ISilo(configData1.silo).initialize(siloConfig, initData.interestRateModelConfig1);

        (IInterestRateModelV2Config modelConfigAddr0,,) =
            InterestRateModelV2(configData0.interestRateModel).getSetup(configData0.silo);
        IInterestRateModelV2.Config memory irmConfigUsed0 = modelConfigAddr0.getConfig();

        (SiloConfigData.ConfigData memory siloConfigData,) = siloData.getConfigData(SILO_TO_DEPLOY);
        IInterestRateModelV2.Config memory irmConfigExpected0 =
            modelData.getConfigData(siloConfigData.interestRateModelConfig0);

        assertEq(abi.encode(irmConfigUsed0), abi.encode(irmConfigExpected0));

        (IInterestRateModelV2Config modelConfigAddr1,,) =
            InterestRateModelV2(configData1.interestRateModel).getSetup(configData1.silo);
        IInterestRateModelV2.Config memory irmConfigUsed1 = modelConfigAddr1.getConfig();

        IInterestRateModelV2.Config memory irmConfigExpected1 =
            modelData.getConfigData(siloConfigData.interestRateModelConfig1);

        assertEq(abi.encode(irmConfigUsed1), abi.encode(irmConfigExpected1));

        // TODO: check IHookReceiver initialize when it's supported in deploy scripts

        vm.expectRevert("Initializable: contract is already initialized");
        IShareToken(configData0.protectedShareToken).initialize(ISilo(configData0.silo), address(0));

        vm.expectRevert("Initializable: contract is already initialized");
        IShareToken(configData0.collateralShareToken).initialize(ISilo(configData0.silo), address(0));

        vm.expectRevert("Initializable: contract is already initialized");
        IShareToken(configData0.debtShareToken).initialize(ISilo(configData0.silo), address(0));

        vm.expectRevert("Initializable: contract is already initialized");
        IShareToken(configData1.protectedShareToken).initialize(ISilo(configData1.silo), address(0));

        vm.expectRevert("Initializable: contract is already initialized");
        IShareToken(configData1.collateralShareToken).initialize(ISilo(configData1.silo), address(0));

        vm.expectRevert("Initializable: contract is already initialized");
        IShareToken(configData1.debtShareToken).initialize(ISilo(configData1.silo), address(0));

        assertEq(siloFactory.ownerOf(1), initData.deployer);
    }
}
