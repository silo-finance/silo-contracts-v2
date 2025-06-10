// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {SiloVerifier} from "silo-core/deploy/silo/verifier/SiloVerifier.sol";
import {InterestRateModelConfigData} from "silo-core/deploy/input-readers/InterestRateModelConfigData.sol";
import {InterestRateModelV2, IInterestRateModelV2} from "silo-core/contracts/interestRateModel/InterestRateModelV2.sol";
import {IInterestRateModelV2Config} from "silo-core/contracts/interfaces/IInterestRateModelV2Config.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IGaugeHookReceiver, GaugeHookReceiver} from "silo-core/contracts/hooks/gauge/GaugeHookReceiver.sol";
import {ISiloIncentivesController} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

/*
    FOUNDRY_PROFILE=core_test forge test -vv --match-contract SiloVerifierScriptTest --ffi
*/
contract SiloVerifierScriptTest is Test {
    ISiloConfig constant WS_USDC_CONFIG = ISiloConfig(0x062A36Bbe0306c2Fd7aecdf25843291fBAB96AD2);
    address constant USDC = 0x29219dd400f2Bf60E5a23d13Be72B486D4038894;
    address constant EXAMPLE_HOOK_RECEIVER = 0x2D3d269334485d2D876df7363e1A50b13220a7D8;

    uint256 constant EXTERNAL_PRICE_0 = 410;
    uint256 constant EXTERNAL_PRICE_1 = 1000;

    function setUp() public {
        vm.createSelectFork(string(abi.encodePacked(vm.envString("RPC_SONIC"))), 7229436);
        AddrLib.init();
    }

    function test_CheckDaoFee() public {
        SiloVerifier verifier = new SiloVerifier(WS_USDC_CONFIG, false, EXTERNAL_PRICE_0, EXTERNAL_PRICE_1);
        assertEq(verifier.verify(), 0, "no errors before mock");

        (address silo0, address silo1) = WS_USDC_CONFIG.getSilos();
        ISiloConfig.ConfigData memory configData0 = WS_USDC_CONFIG.getConfig(silo0);
        ISiloConfig.ConfigData memory configData1 = WS_USDC_CONFIG.getConfig(silo1);

        configData0.daoFee = 1;
        configData1.daoFee = 10**18;

        vm.mockCall(
            address(WS_USDC_CONFIG),
            abi.encodeWithSelector(ISiloConfig.getConfig.selector, silo0),
            abi.encode(configData0)
        );

        vm.mockCall(
            address(WS_USDC_CONFIG),
            abi.encodeWithSelector(ISiloConfig.getConfig.selector, silo1),
            abi.encode(configData1)
        );

        verifier = new SiloVerifier(WS_USDC_CONFIG, false, EXTERNAL_PRICE_0, EXTERNAL_PRICE_1);
        assertEq(verifier.verify(), 2, "2 errors after breaking dao fee in both Silos");
    }

    function test_CheckDeployerFee() public {
        SiloVerifier verifier = new SiloVerifier(WS_USDC_CONFIG, false, EXTERNAL_PRICE_0, EXTERNAL_PRICE_1);
        assertEq(verifier.verify(), 0, "no errors before mock");

        (address silo0, address silo1) = WS_USDC_CONFIG.getSilos();
        ISiloConfig.ConfigData memory configData0 = WS_USDC_CONFIG.getConfig(silo0);
        ISiloConfig.ConfigData memory configData1 = WS_USDC_CONFIG.getConfig(silo1);

        configData0.deployerFee = 12;
        configData1.deployerFee = 22;

        vm.mockCall(
            address(WS_USDC_CONFIG),
            abi.encodeWithSelector(ISiloConfig.getConfig.selector, silo0),
            abi.encode(configData0)
        );

        vm.mockCall(
            address(WS_USDC_CONFIG),
            abi.encodeWithSelector(ISiloConfig.getConfig.selector, silo1),
            abi.encode(configData1)
        );

        verifier = new SiloVerifier(WS_USDC_CONFIG, false, EXTERNAL_PRICE_0, EXTERNAL_PRICE_1);
        assertEq(verifier.verify(), 2, "2 errors after breaking deployer fee in both Silos");
    }

    function test_CheckLiquidationFee() public {
        SiloVerifier verifier = new SiloVerifier(WS_USDC_CONFIG, false, EXTERNAL_PRICE_0, EXTERNAL_PRICE_1);
        assertEq(verifier.verify(), 0, "no errors before mock");

        (address silo0, address silo1) = WS_USDC_CONFIG.getSilos();
        ISiloConfig.ConfigData memory configData0 = WS_USDC_CONFIG.getConfig(silo0);
        ISiloConfig.ConfigData memory configData1 = WS_USDC_CONFIG.getConfig(silo1);

        configData0.liquidationFee = 10**18;
        configData1.liquidationFee = 10**18 / 2;

        vm.mockCall(
            address(WS_USDC_CONFIG),
            abi.encodeWithSelector(ISiloConfig.getConfig.selector, silo0),
            abi.encode(configData0)
        );

        vm.mockCall(
            address(WS_USDC_CONFIG),
            abi.encodeWithSelector(ISiloConfig.getConfig.selector, silo1),
            abi.encode(configData1)
        );

        verifier = new SiloVerifier(WS_USDC_CONFIG, false, EXTERNAL_PRICE_0, EXTERNAL_PRICE_1);
        assertEq(verifier.verify(), 2, "2 errors after breaking liquidation fee in both Silos");
    }

    function test_CheckFlashloanFee() public {
        SiloVerifier verifier = new SiloVerifier(WS_USDC_CONFIG, false, EXTERNAL_PRICE_0, EXTERNAL_PRICE_1);
        assertEq(verifier.verify(), 0, "no errors before mock");

        (address silo0, address silo1) = WS_USDC_CONFIG.getSilos();
        ISiloConfig.ConfigData memory configData0 = WS_USDC_CONFIG.getConfig(silo0);
        ISiloConfig.ConfigData memory configData1 = WS_USDC_CONFIG.getConfig(silo1);

        configData0.flashloanFee = 10**18;
        configData1.flashloanFee = 10**18 / 2;

        vm.mockCall(
            address(WS_USDC_CONFIG),
            abi.encodeWithSelector(ISiloConfig.getConfig.selector, silo0),
            abi.encode(configData0)
        );

        vm.mockCall(
            address(WS_USDC_CONFIG),
            abi.encodeWithSelector(ISiloConfig.getConfig.selector, silo1),
            abi.encode(configData1)
        );

        verifier = new SiloVerifier(WS_USDC_CONFIG, false, EXTERNAL_PRICE_0, EXTERNAL_PRICE_1);
        assertEq(verifier.verify(), 2, "2 errors after breaking flashloan fee in both Silos");
    }

    function test_CheckSiloImplementation() public {
        SiloVerifier verifier = new SiloVerifier(WS_USDC_CONFIG, false, EXTERNAL_PRICE_0, EXTERNAL_PRICE_1);
        assertEq(verifier.verify(), 0, "no errors before mock");

        (address silo0, address silo1) = WS_USDC_CONFIG.getSilos();
        ISiloConfig.ConfigData memory configData0 = WS_USDC_CONFIG.getConfig(silo0);
        ISiloConfig.ConfigData memory configData1 = WS_USDC_CONFIG.getConfig(silo1);

        configData0.silo = USDC;
        configData1.silo = USDC;

        vm.mockCall(
            address(WS_USDC_CONFIG),
            abi.encodeWithSelector(ISiloConfig.getConfig.selector, silo0),
            abi.encode(configData0)
        );

        vm.mockCall(
            address(WS_USDC_CONFIG),
            abi.encodeWithSelector(ISiloConfig.getConfig.selector, silo1),
            abi.encode(configData1)
        );

        verifier = new SiloVerifier(WS_USDC_CONFIG, false, EXTERNAL_PRICE_0, EXTERNAL_PRICE_1);
        assertEq(verifier.verify(), 2, "2 errors after breaking Silo implementation in both Silos");
    }

    function test_CheckMaxLtvLtLiquidationFee() public {
        SiloVerifier verifier = new SiloVerifier(WS_USDC_CONFIG, false, EXTERNAL_PRICE_0, EXTERNAL_PRICE_1);
        assertEq(verifier.verify(), 0, "no errors before mock");

        (address silo0, address silo1) = WS_USDC_CONFIG.getSilos();
        ISiloConfig.ConfigData memory configData0 = WS_USDC_CONFIG.getConfig(silo0);
        ISiloConfig.ConfigData memory configData1 = WS_USDC_CONFIG.getConfig(silo1);

        configData0.maxLtv = 0;
        configData0.lt = 0;
        configData0.liquidationFee = 0;

        configData1.maxLtv = 0;
        configData1.lt = 0;
        configData1.liquidationFee = 0;
        

        vm.mockCall(
            address(WS_USDC_CONFIG),
            abi.encodeWithSelector(ISiloConfig.getConfig.selector, silo0),
            abi.encode(configData0)
        );

        vm.mockCall(
            address(WS_USDC_CONFIG),
            abi.encodeWithSelector(ISiloConfig.getConfig.selector, silo1),
            abi.encode(configData1)
        );

        verifier = new SiloVerifier(WS_USDC_CONFIG, false, EXTERNAL_PRICE_0, EXTERNAL_PRICE_1);
        assertEq(verifier.verify(), 0, "0 errors when maxLTV, LT and liquidation fee are zeros");

        configData0.maxLtv = 0;
        configData0.lt = 10**18 / 2;
        configData0.liquidationFee = 10**18 / 100;

        configData1.maxLtv = 10**18 * 75 / 100;
        configData1.lt = 0;
        configData1.liquidationFee = 10**18 / 100;
        

        vm.mockCall(
            address(WS_USDC_CONFIG),
            abi.encodeWithSelector(ISiloConfig.getConfig.selector, silo0),
            abi.encode(configData0)
        );

        vm.mockCall(
            address(WS_USDC_CONFIG),
            abi.encodeWithSelector(ISiloConfig.getConfig.selector, silo1),
            abi.encode(configData1)
        );

        verifier = new SiloVerifier(WS_USDC_CONFIG, false, EXTERNAL_PRICE_0, EXTERNAL_PRICE_1);
        assertEq(verifier.verify(), 2, "2 errors when one of the maxLTV, LT and liquidation fee is zero");
    }

    function test_CheckHookOwner() public {
        SiloVerifier verifier = new SiloVerifier(WS_USDC_CONFIG, false, EXTERNAL_PRICE_0, EXTERNAL_PRICE_1);
        assertEq(verifier.verify(), 0, "no errors before mock");

        (address silo0, address silo1) = WS_USDC_CONFIG.getSilos();
        ISiloConfig.ConfigData memory configData0 = WS_USDC_CONFIG.getConfig(silo0);
        ISiloConfig.ConfigData memory configData1 = WS_USDC_CONFIG.getConfig(silo1);

        vm.mockCall(
            address(configData0.hookReceiver),
            abi.encodeWithSelector(Ownable.owner.selector),
            abi.encode(address(1))
        );

        vm.mockCall(
            address(configData1.hookReceiver),
            abi.encodeWithSelector(Ownable.owner.selector),
            abi.encode(address(2))
        );

        verifier = new SiloVerifier(WS_USDC_CONFIG, false, EXTERNAL_PRICE_0, EXTERNAL_PRICE_1);
        assertEq(verifier.verify(), 2, "2 errors after breaking hook receiver owner in both Silos");
    }

    function test_CheckIncentivesOwner() public {
        SiloVerifier verifier = new SiloVerifier(WS_USDC_CONFIG, false, EXTERNAL_PRICE_0, EXTERNAL_PRICE_1);
        assertEq(verifier.verify(), 0, "no errors before mock");

        (, address silo1) = WS_USDC_CONFIG.getSilos();
        ISiloConfig.ConfigData memory configData1 = WS_USDC_CONFIG.getConfig(silo1);

        ISiloIncentivesController incentives1 = IGaugeHookReceiver(configData1.hookReceiver).configuredGauges(
            IShareToken(configData1.collateralShareToken)
        );

       vm.mockCall(
            address(incentives1),
            abi.encodeWithSelector(Ownable.owner.selector),
            abi.encode(address(2))
        );

        verifier = new SiloVerifier(WS_USDC_CONFIG, false, EXTERNAL_PRICE_0, EXTERNAL_PRICE_1);
        assertEq(verifier.verify(), 1, "1 error after breaking incentives owner in Silo1 with incentives");
    }

    function test_CheckShareTokensInGauge() public {
        SiloVerifier verifier = new SiloVerifier(WS_USDC_CONFIG, false, EXTERNAL_PRICE_0, EXTERNAL_PRICE_1);
        assertEq(verifier.verify(), 0, "no errors before mock");

        (, address silo1) = WS_USDC_CONFIG.getSilos();
        ISiloConfig.ConfigData memory configData1 = WS_USDC_CONFIG.getConfig(silo1);

        ISiloIncentivesController incentives1 = IGaugeHookReceiver(configData1.hookReceiver).configuredGauges(
            IShareToken(configData1.collateralShareToken)
        );

       vm.mockCall(
            address(incentives1),
            abi.encodeWithSelector(ISiloIncentivesController.SHARE_TOKEN.selector),
            abi.encode(address(2))
        );

        verifier = new SiloVerifier(WS_USDC_CONFIG, false, EXTERNAL_PRICE_0, EXTERNAL_PRICE_1);
        assertEq(verifier.verify(), 1, "1 error after breaking share_token in Silo1 gauge with incentives");
    }

    function test_CheckIrmConfig() public {
        SiloVerifier verifier = new SiloVerifier(WS_USDC_CONFIG, false, EXTERNAL_PRICE_0, EXTERNAL_PRICE_1);
        assertEq(verifier.verify(), 0, "no errors before mock");

        (address silo0, address silo1) = WS_USDC_CONFIG.getSilos();
        ISiloConfig.ConfigData memory configData0 = WS_USDC_CONFIG.getConfig(silo0);
        ISiloConfig.ConfigData memory configData1 = WS_USDC_CONFIG.getConfig(silo1);

        IInterestRateModelV2Config irmV2Config0 =
            InterestRateModelV2(configData0.interestRateModel).irmConfig();

        IInterestRateModelV2.Config memory irmConfig0 = irmV2Config0.getConfig();

        IInterestRateModelV2Config irmV2Config1 =
            InterestRateModelV2(configData1.interestRateModel).irmConfig();

        IInterestRateModelV2.Config memory irmConfig1 = irmV2Config1.getConfig();

        irmConfig0.uopt = 11;
        irmConfig1.ucrit = 22;

        vm.mockCall(
            address(irmV2Config0),
            abi.encodeWithSelector(IInterestRateModelV2Config.getConfig.selector),
            abi.encode(irmConfig0)
        );

        vm.mockCall(
            address(irmV2Config1),
            abi.encodeWithSelector(IInterestRateModelV2Config.getConfig.selector),
            abi.encode(irmConfig1)
        );

        verifier = new SiloVerifier(WS_USDC_CONFIG, false, EXTERNAL_PRICE_0, EXTERNAL_PRICE_1);
        assertEq(verifier.verify(), 2, "2 errors after breaking IRM config in both Silos");
    }

    function test_CheckPriceDoesNotReturnZero() public {
        SiloVerifier verifier = new SiloVerifier(WS_USDC_CONFIG, false, EXTERNAL_PRICE_0, EXTERNAL_PRICE_1);
        assertEq(verifier.verify(), 0, "no errors before mock");

        (address silo0,) = WS_USDC_CONFIG.getSilos();
        ISiloConfig.ConfigData memory configData0 = WS_USDC_CONFIG.getConfig(silo0);

        vm.mockCall(
            address(configData0.solvencyOracle),
            abi.encodeWithSelector(ISiloOracle.quote.selector),
            abi.encode(uint256(0))
        );

        verifier = new SiloVerifier(WS_USDC_CONFIG, false, EXTERNAL_PRICE_0, EXTERNAL_PRICE_1);

        assertEq(
            verifier.verify(),
            2,
            "2 errors after breaking oracle to return zeros. 1 for price does not return zero, 1 for external prices"
        );
    }

    function test_CheckExternalPrices() public {
        SiloVerifier verifier = new SiloVerifier(WS_USDC_CONFIG, false, EXTERNAL_PRICE_0, EXTERNAL_PRICE_1);
        assertEq(verifier.verify(), 0, "no errors for original prices");

        verifier = new SiloVerifier(ISiloConfig(0xefA367570B11f8745B403c0D458b9D2EAf424686), false, 1000, 1000);
        assertEq(verifier.verify(), 0, "no errors for single oracle case");

        verifier = new SiloVerifier(WS_USDC_CONFIG, false, EXTERNAL_PRICE_0 * 102 / 100, EXTERNAL_PRICE_1);
        assertEq(verifier.verify(), 1, "1 error for 2% price deviation");

        verifier = new SiloVerifier(WS_USDC_CONFIG, false, 0, 0);
        assertEq(verifier.verify(), 1, "1 error when no prices provided");
    }

    function test_CheckQuoteIsLinearFunction() public {
        SiloVerifier verifier = new SiloVerifier(WS_USDC_CONFIG, false, EXTERNAL_PRICE_0, EXTERNAL_PRICE_1);
        assertEq(verifier.verify(), 0, "no errors before mock");

        (address silo0, address silo1) = WS_USDC_CONFIG.getSilos();
        ISiloConfig.ConfigData memory configData0 = WS_USDC_CONFIG.getConfig(silo0);
        ISiloConfig.ConfigData memory configData1 = WS_USDC_CONFIG.getConfig(silo1);

        vm.mockCall(
            address(configData0.solvencyOracle),
            abi.encodeWithSelector(ISiloOracle.quote.selector),
            abi.encode(EXTERNAL_PRICE_0)
        );

        vm.mockCall(
            address(configData1.solvencyOracle),
            abi.encodeWithSelector(ISiloOracle.quote.selector),
            abi.encode(EXTERNAL_PRICE_1)
        );

        verifier = new SiloVerifier(WS_USDC_CONFIG, false, EXTERNAL_PRICE_0, EXTERNAL_PRICE_1);
        assertEq(verifier.verify(), 2, "2 errors after breaking linear property in oracles for both Silos");
    }

    function test_CheckQuoteLargeAmounts() public {
        SiloVerifier verifier = new SiloVerifier(WS_USDC_CONFIG, false, EXTERNAL_PRICE_0, EXTERNAL_PRICE_1);
        assertEq(verifier.verify(), 0, "no errors before mock");

        (address silo0, address silo1) = WS_USDC_CONFIG.getSilos();
        ISiloConfig.ConfigData memory configData0 = WS_USDC_CONFIG.getConfig(silo0);
        ISiloConfig.ConfigData memory configData1 = WS_USDC_CONFIG.getConfig(silo1);

        configData0.solvencyOracle = USDC;
        configData1.solvencyOracle = USDC;

        vm.mockCall(
            address(WS_USDC_CONFIG),
            abi.encodeWithSelector(ISiloConfig.getConfig.selector, silo0),
            abi.encode(configData0)
        );

        vm.mockCall(
            address(WS_USDC_CONFIG),
            abi.encodeWithSelector(ISiloConfig.getConfig.selector, silo1),
            abi.encode(configData1)
        );

        verifier = new SiloVerifier(WS_USDC_CONFIG, false, EXTERNAL_PRICE_0, EXTERNAL_PRICE_1);

        assertEq(
            verifier.verify(),
            3,
            "3 errors after making oracles revert for large amounts. 2 for quote large amounts, 1 for external price check"
        );
    }
}
