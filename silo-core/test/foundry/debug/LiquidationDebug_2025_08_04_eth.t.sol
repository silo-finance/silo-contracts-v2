// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console2} from "forge-std/console2.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {LiquidationHelper} from "silo-core/contracts/utils/liquidationHelper/LiquidationHelper.sol";
import {SiloLens} from "silo-core/contracts/SiloLens.sol";

import {ILiquidationHelper} from "silo-core/contracts/interfaces/ILiquidationHelper.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";
import {ManualLiquidationHelper} from "silo-core/contracts/utils/liquidationHelper/ManualLiquidationHelper.sol";

/*
FOUNDRY_PROFILE=core_test forge test --mc LiquidationDebug_2025_08_04_eth --ffi -vvv
*/
contract LiquidationDebug_2025_08_04_eth is IntegrationTest {
    SiloLens constant internal lens = SiloLens(0xC0e1bcFB1Ed68688B0d589A6807d05cF2D68b22b);
    // IPartialLiquidation constant internal hook = IPartialLiquidation(0xDdBa71380230a3a5ab7094d9c774A6C5852a0fFC);
    // ILiquidationHelper constant internal helper = ILiquidationHelper(0xd98C025cf5d405FE3385be8C9BE64b219EC750F8);
    ILiquidationHelper internal helper;
    ManualLiquidationHelper internal manualHelper;

    function setUp() public {
        vm.createSelectFork(
            vm.envString("RPC_MAINNET"),
            23067360
        );

        helper = LiquidationHelper(payable(0xefca82B9B9fC3c362B59767e416bB5cE72c6DfeF));
        manualHelper = ManualLiquidationHelper(payable(0x9BA51a66FF7e8043f43A793EA70c82472490cd42));

        vm.label(address(helper), "LiquidationHelper");
        vm.label(address(manualHelper), "ManualLiquidationHelper");
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mc LiquidationDebug_2025_08_04_eth --mt test_skip_manual_liquidation --ffi -vvv

   
Unhealthy Positions Details:
• Borrower: 0xA2b582dCE6361a0b735A59fF69301318D42a6f20
• Silo: 0xCE6aB1c71981e79Cd30052C521c162674251018a
• Health: 0.999
• Last Failed Liquidation: N/A


    */
    function test_skip_manual_liquidation() public {

        address user = 0xA2b582dCE6361a0b735A59fF69301318D42a6f20;
        ISilo silo = ISilo(0xCE6aB1c71981e79Cd30052C521c162674251018a);

        IERC20 usdc = IERC20(0x29219dd400f2Bf60E5a23d13Be72B486D4038894);
        vm.label(address(usdc), "usdc");

        IERC20 wS = IERC20(0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38);
        vm.label(address(wS), "wS");

        console2.log("Liquidation Debug 2025-08-04");
        console2.log("block number: ", block.number);
        console2.log("user: ", user);

        _print(silo, user);
    }


    function _print(ISilo _silo, address _user) internal view {
        ISiloConfig config = ISiloConfig(_silo.config());
        (
            ISiloConfig.ConfigData memory collateralCfg, ISiloConfig.ConfigData memory debtCfg
        ) = config.getConfigsForSolvency(_user);

        console2.log("---------------------------");
        console2.log("collateral silo: ", collateralCfg.silo);
        console2.log("debt silo: ", debtCfg.silo);
        console2.log("collateral Liquidation Threshold: ", collateralCfg.lt);
        console2.log(".     debt Liquidation Threshold: ", debtCfg.lt);
        console2.log("                        user LTV: ", lens.getUserLTV(_silo, _user));
        console2.log("                    user solvent? ", _silo.isSolvent(_user) ? "YES" : "NO!");
    }
}
