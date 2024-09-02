// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IShareTokenInitializable} from "silo-core/contracts/interfaces/IShareTokenInitializable.sol";
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
forge test -vv --ffi --mc SiloFactoryTest
*/
contract SiloFactoryTest is SiloLittleHelper, IntegrationTest {
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
    forge test -vv --ffi --mt test_burnCreatedSiloToken
    */
    function test_burnCreatedSiloToken() public {
        uint256 firstSiloId = 1;

        (,address owner) = siloFactory.getFeeReceivers(address(silo0));

        assertNotEq(owner, address(0), "owner is 0");

        bool isSilo = siloFactory.isSilo(address(silo0));
        assertTrue(isSilo, "silo0 is not a silo");
        isSilo = siloFactory.isSilo(address(silo1));
        assertTrue(isSilo, "silo1 is not a silo");

        vm.prank(owner);
        siloFactory.burn(firstSiloId);

        (,owner) = siloFactory.getFeeReceivers(address(silo0));

        assertEq(owner, address(0), "owner is not 0 after burn");

        isSilo = siloFactory.isSilo(address(silo0));
        assertTrue(isSilo, "silo0 is not a silo after burn");
        isSilo = siloFactory.isSilo(address(silo1));
        assertTrue(isSilo, "silo1 is not a silo after burn");
    }

    /*
    forge test -vv --ffi --mt test_isSilo
    */
    function test_isSilo() public {
        // 1. Test real silos
        bool isSilo = siloFactory.isSilo(address(silo0));
        assertTrue(isSilo, "silo0 is not a silo");
        isSilo = siloFactory.isSilo(address(silo1));
        assertTrue(isSilo, "silo1 is not a silo");

        // 2. Test empty address
        isSilo = siloFactory.isSilo(address(0));
        assertFalse(isSilo, "address(0) is a silo");

        // 3. Some random address
        isSilo = siloFactory.isSilo(makeAddr("random"));
        assertFalse(isSilo, "random is a silo");
    }
}
