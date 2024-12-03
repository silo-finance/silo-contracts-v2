// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {InterestRateModelV2} from "silo-core/contracts/interestRateModel/InterestRateModelV2.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IInterestRateModelV2} from "silo-core/contracts/interfaces/IInterestRateModelV2.sol";
import {IInterestRateModelV2Config} from "silo-core/contracts/interfaces/IInterestRateModelV2Config.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {SiloLens} from "silo-core/contracts/SiloLens.sol";

import {console} from "forge-std/console.sol";

//interface IRMGetters {
//    struct Setup {
//        // ri ≥ 0 – initial value of the integrator
//        int128 ri;
//        // Tcrit ≥ 0 - the time during which the utilization exceeds the critical value
//        int128 Tcrit;
//        IInterestRateModelV2Config config;
//    }
//
//    function getSetup(address _silo) external view returns (Setup memory setup);
//}

// FOUNDRY_PROFILE=core-test forge test --mc SiloDebugTest --ffi -vvv
contract DebugIrmZeroTest is IntegrationTest {
    ISiloConfig constant internal _SILO_CFG = ISiloConfig(0x02ED2727D2Dc29b24E5AC9A7d64f2597CFb74bAB);

    InterestRateModelV2 debugIRM;

    function setUp() public {
        vm.createSelectFork(
            getChainRpcUrl(ARBITRUM_ONE_ALIAS),
            280680615
        );

        console.log("time %s", block.timestamp); // 1732729846
        vm.label(0xC48dFAd68A909e01eE2e82EFbb3F406e3549349C, "SiloLendingLib");

        debugIRM = new InterestRateModelV2();
    }

    /*
    FOUNDRY_PROFILE=core-test forge test --mc DebugIrmZeroTest --mt test_debug_irm_zero --ffi -vvv
    */
    function test_debug_irm_zero() public {
        (address silo0, address silo1) = _SILO_CFG.getSilos();
        vm.label(silo0, "silo0");
        vm.label(silo1, "silo1");

        _print(silo1);
    }

    function _print(address _silo) public {
        vm.warp(block.timestamp + 100000 days);
//        console.log("time %s", block.timestamp); // 1732729846

//        emit log_named_decimal_uint("accrueInterest1", ISilo(_silo).accrueInterest(), 18);

        ISiloConfig.ConfigData memory config1 = _SILO_CFG.getConfig(_silo);

        vm.label(config1.interestRateModel, "IRM");
        InterestRateModelV2 irm = InterestRateModelV2(config1.interestRateModel);

        console.log("IRM:", config1.interestRateModel);
        console.log("irmConfig:", address(irm.irmConfig()));
        vm.label(address(irm.irmConfig()), "irmConfig");

        debugIRM.initialize(address(irm.irmConfig()));
//        console.log("getCurrentInterestRate:", debugIRM.getCurrentInterestRate(_silo, block.timestamp));

        (int128 ri, int128 Tcrit) = irm.getSetup(address(_silo));
        console.log("ri:");
        console.logInt(ri);
        console.log("Tcrit:");
        console.logInt(Tcrit);
        console.log("--------");

        IInterestRateModelV2.Config memory irmConfig = irm.irmConfig().getConfig();
        // config.uopt = _UOPT;
        //        config.ucrit = _UCRIT;
        //        config.ulow = _ULOW;
        //        config.ki = _KI;
        //        config.kcrit = _KCRIT;
        //        config.klow = _KLOW;
        //        config.klin = _KLIN;
        //        config.beta = _BETA;
//        console.log("uopt:");
//        console.logInt(irmConfig.uopt);
//        console.log("ucrit:");
//        console.logInt(irmConfig.ucrit);
//        console.log("ulow:");
//        console.logInt(irmConfig.ulow);
//        console.log("ki:");
//        console.logInt(irmConfig.ki);
//        console.log("kcrit:");
//        console.logInt(irmConfig.kcrit);
//        console.log("klin:");
//        console.logInt(irmConfig.klin);

        (,, address debtToken) = _SILO_CFG.getShareTokens(address(_silo));

        emit log_named_decimal_uint("debt shares", IShareToken(debtToken).totalSupply(), IShareToken(debtToken).decimals());
//        emit log_named_decimal_uint("accrueInterest", ISilo(_silo).accrueInterest(), 16);

        ISilo.UtilizationData memory data = ISilo(_silo).utilizationData();
        emit log_named_uint("interestRateTimestamp", data.interestRateTimestamp);
        emit log_named_decimal_uint("debtAssets", data.debtAssets, 18);
        emit log_named_decimal_uint("collateralAssets", data.collateralAssets, 18);
        emit log_named_decimal_uint("%", data.debtAssets * 1e18 / data.collateralAssets, 18);

        console.log("DEBUG.......");

        vm.prank(_silo);
        // uint256 _collateralAssets,
        //        uint256 _debtAssets,
        //        uint256 _interestRateTimestamp
        console.log("getCompoundInterestRateAndUpdate:", debugIRM.getCompoundInterestRateAndUpdate(data.collateralAssets, data.debtAssets, data.interestRateTimestamp));

        ( ri,  Tcrit) = debugIRM.getSetup(address(_silo));
        console.log("ri:");
        console.logInt(ri);
        console.log("Tcrit:");
        console.logInt(Tcrit);
        console.log("--------");

//        emit log_named_address("accrueInterest1", ISilo(_silo).accrueInterest(), 18);

//        console.log("IRM", config1.interestRateModel);
    }
}
