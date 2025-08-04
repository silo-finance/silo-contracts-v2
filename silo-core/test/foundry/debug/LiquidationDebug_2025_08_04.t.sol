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
FOUNDRY_PROFILE=core_test forge test --mc LiquidationDebug_2025_08_04 --ffi -vvv
*/
contract LiquidationDebug_2025_08_04 is IntegrationTest {
    SiloLens constant internal lens = SiloLens(0xB95AD415b0fcE49f84FbD5B26b14ec7cf4822c69);
    IPartialLiquidation constant internal hook = IPartialLiquidation(0xDdBa71380230a3a5ab7094d9c774A6C5852a0fFC);
    // ILiquidationHelper constant internal helper = ILiquidationHelper(0xd98C025cf5d405FE3385be8C9BE64b219EC750F8);
    ILiquidationHelper internal helper;
    ManualLiquidationHelper internal manualHelper;

    address internal swapAllowanceHolder = 0xaC041Df48dF9791B0654f1Dbbf2CC8450C5f2e9D;
    address internal weth = 0x4200000000000000000000000000000000000006;

    function setUp() public {
        vm.createSelectFork(
            vm.envString("RPC_SONIC"),
            41585402
        );

        helper = LiquidationHelper(payable(0xefca82B9B9fC3c362B59767e416bB5cE72c6DfeF));
        manualHelper = ManualLiquidationHelper(payable(0x9BA51a66FF7e8043f43A793EA70c82472490cd42));

        vm.label(weth, "WETH");
        vm.label(address(helper), "LiquidationHelper");
        vm.label(address(manualHelper), "ManualLiquidationHelper");
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --mc LiquidationDebug_2025_08_04 --mt test_skip_manual_liquidation --ffi -vvv

   
   Network   : sonic
Silo      : 0x322e1d5384aa4ED66AeCa770B95686271de61dc3
Borrower  : 0xE643C33AE1f8F6B0EC5219E84A818d79ECCfC5aF
Debt      :
    Amount: 33306690
    Address: 0x29219dd400f2Bf60E5a23d13Be72B486D4038894
Collateral:
    Amount: 119501229385627106703
    Address: 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38

    */
    function test_skip_manual_liquidation() public {
        vm.createSelectFork(
            vm.envString("RPC_SONIC"),
            41590600
        );

        address user = 0xE643C33AE1f8F6B0EC5219E84A818d79ECCfC5aF;
        ISilo silo = ISilo(0x322e1d5384aa4ED66AeCa770B95686271de61dc3);

        IERC20 usdc = IERC20(0x29219dd400f2Bf60E5a23d13Be72B486D4038894);
        vm.label(address(usdc), "usdc");

        IERC20 wS = IERC20(0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38);
        vm.label(address(wS), "wS");

        console2.log("Liquidation Debug 2025-08-04");
        console2.log("block number: ", block.number);
        console2.log("user: ", user);

        _print(silo, user);

        address usdcWhale = 0xf89d7b9c864f589bbF53a82105107622B35EaA40;

        vm.prank(usdcWhale);
        usdc.transfer(address(this), 50e6);

        usdc.approve(address(manualHelper), 50e6);


        address wSwhale = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

        // deposit for user to enable liquidaiton
        vm.prank(wSwhale);
        usdc.approve(address(silo), type(uint256).max);

        vm.prank(wSwhale);
        silo.deposit(1000, user);

        manualHelper.executeLiquidation(silo, user, type(uint256).max, true);
        // manualHelper.executeLiquidation(silo, user, type(uint256).max, true);
    }


    function _print(ISilo _silo, address _user) internal view {
        ISiloConfig config = ISiloConfig(_silo.config());
        (
            ISiloConfig.ConfigData memory collateralCfg, ISiloConfig.ConfigData memory debtCfg
        ) = config.getConfigsForSolvency(_user);

        console2.log("collateral silo: ", collateralCfg.silo);
        console2.log("debt silo: ", debtCfg.silo);
        console2.log("collateral Liquidation Threshold: ", collateralCfg.lt);
        console2.log(".     debt Liquidation Threshold: ", debtCfg.lt);
        console2.log("                        user LTV: ", lens.getUserLTV(_silo, _user));
    }
}
