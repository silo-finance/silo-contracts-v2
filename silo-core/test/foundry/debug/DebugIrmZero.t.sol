// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

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

    function setUp() public {
        vm.createSelectFork(
            getChainRpcUrl(ARBITRUM_ONE_ALIAS),
            280680615
        );

        console.log("time %s", block.timestamp); // 1732729846
        vm.label(0xC48dFAd68A909e01eE2e82EFbb3F406e3549349C, "SiloLendingLib");
    }

    /*
    FOUNDRY_PROFILE=core-test forge test --mc DebugIrmZeroTest --mt test_debug_irm_zero --ffi -vvv
    */
    function test_debug_irm_zero() public {
        (address silo0, address silo1) = _SILO_CFG.getSilos();
        vm.label(silo0, "silo0");
        vm.label(silo1, "silo1");

//        ISiloConfig.ConfigData memory config0 = _SILO_CFG.getConfig(silo0);
        ISiloConfig.ConfigData memory config1 = _SILO_CFG.getConfig(silo1);

        vm.label(config1.interestRateModel, "IRM_1");
        IInterestRateModelV2 irm = IInterestRateModelV2(config1.interestRateModel);

        (,, address debtToken) = _SILO_CFG.getShareTokens(silo1);

        emit log_named_decimal_uint("debt shares", IShareToken(debtToken).totalSupply(), IShareToken(debtToken).decimals());
        emit log_named_decimal_uint("accrueInterest0", ISilo(silo0).accrueInterest(), 18);
        emit log_named_decimal_uint("accrueInterest1", ISilo(silo1).accrueInterest(), 18);
        console.log("IRM", config1.interestRateModel);
    }
}
