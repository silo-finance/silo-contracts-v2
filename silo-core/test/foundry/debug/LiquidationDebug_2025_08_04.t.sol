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
import {BaseHookReceiver} from "silo-core/contracts/hooks/_common/BaseHookReceiver.sol";

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

        ISilo debtsilo = ISilo(0xf55902DE87Bd80c6a35614b48d7f8B612a083C12);

        // deposit for user to enable liquidaiton
        // vm.prank(wSwhale);
        // wS.approve(address(debtsilo), type(uint256).max);

        // vm.prank(wSwhale);
        // debtsilo.mint(1000, user, ISilo.CollateralType.Protected);

        _print(silo, user);

        // manualHelper.executeLiquidation(silo, user);
        manualHelper.executeLiquidation(silo, user, type(uint256).max, true);

        _print(silo, user);
    }

    /*
        FOUNDRY_PROFILE=core_test forge test --mc LiquidationDebug_2025_08_04 --mt test_liquidation_with_sToken_fix --ffi -vvv

    {
        "_flashLoanFrom": "0xA1627a0E1d0ebcA9326D2219B84Df0c600bed4b1",
        "_debtAsset": "0x29219dd400f2Bf60E5a23d13Be72B486D4038894",
        "_maxDebtToCover": "89303938",
        "_liquidation": {
            "collateralAsset": "0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38",
            "hook": "0x6AAFD9Dd424541885fd79C06FDA96929CFD512f9",
            "user": "0xE643C33AE1f8F6B0EC5219E84A818d79ECCfC5aF"
        },
        "_swapsInputs0x": [
            {
            "allowanceTarget": "0xaC041Df48dF9791B0654f1Dbbf2CC8450C5f2e9D",
            "sellToken": "0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38",
            "swapCallData": "0x83bd37f90001039e2fb66102314ce7b64ce5ce3e5183bc94ad38000129219dd400f2bf60e5a23d13be72b486d403889409128562729f930698b50405a927f907ae1400016b66316dbdbc67115fefc89edbd0bf3658e6836f00000001f363c6d369888f5367e9f1ad7b6a7dae133e874000000000040102050123daec43210101010203000000060101040201ff0000000000000000a4c937817f99829ac4003a3475f17a2f0d6eaf7c039e2fb66102314ce7b64ce5ce3e5183bc94ad3829219dd400f2bf60e5a23d13be72b486d4038894b1bc4b830fcba2184b92e15b9133c4116051803800000000000000000000000000000000"
            }
        ]
}
    */
    function test_liquidation_with_sToken_fix() public {
        vm.createSelectFork(
            vm.envString("RPC_SONIC"),
            41759140
        );

        address user = 0xE643C33AE1f8F6B0EC5219E84A818d79ECCfC5aF;
        ISilo flashLoanFrom = ISilo(0xA1627a0E1d0ebcA9326D2219B84Df0c600bed4b1);
        vm.label(address(flashLoanFrom), "flashLoanFrom");

        address _nativeToken = 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38;
        address _exchangeProxy = 0xaC041Df48dF9791B0654f1Dbbf2CC8450C5f2e9D;
        address payable _tokensReceiver;

        ILiquidationHelper fixedHelper = new LiquidationHelper(_nativeToken, _exchangeProxy, payable(address(this)));

        ILiquidationHelper.LiquidationData memory liquidation = ILiquidationHelper.LiquidationData({
            hook: IPartialLiquidation(0x6AAFD9Dd424541885fd79C06FDA96929CFD512f9),
            collateralAsset: 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38,
            user: user
        });

        ILiquidationHelper.DexSwapInput[] memory dexSwapInput = new ILiquidationHelper.DexSwapInput[](1);

        dexSwapInput[0] = ILiquidationHelper.DexSwapInput({
            sellToken: 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38,
            allowanceTarget: 0xaC041Df48dF9791B0654f1Dbbf2CC8450C5f2e9D,
            swapCallData: abi.encode(
                hex"83bd37f90001039e2fb66102314ce7b64ce5ce3e5183bc94ad38000129219dd400f2bf60e5a23d13be72b486d403889409128562729f930698b50405a927f907ae1400016b66316dbdbc67115fefc89edbd0bf3658e6836f00000001",
                address(0xf363C6d369888F5367e9f1aD7b6a7dAe133e8740),
                hex"00000000040102050123daec43210101010203000000060101040201ff0000000000000000a4c937817f99829ac4003a3475f17a2f0d6eaf7c039e2fb66102314ce7b64ce5ce3e5183bc94ad3829219dd400f2bf60e5a23d13be72b486d4038894b1bc4b830fcba2184b92e15b9133c4116051803800000000000000000000000000000000"
            )
        });

        console2.log("block number: ", block.number);
        console2.log("user: ", user);

        ISiloConfig config = ISiloConfig(BaseHookReceiver(address(liquidation.hook)).siloConfig());
        
        (
            ISiloConfig.ConfigData memory collateralCfg, ISiloConfig.ConfigData memory debtCfg
        ) = config.getConfigsForSolvency(user);

        console2.log("collateral silo: ", collateralCfg.silo);
        console2.log("debt silo: ", debtCfg.silo);
        console2.log("collateral Liquidation Threshold: ", collateralCfg.lt);
        console2.log(".     debt Liquidation Threshold: ", debtCfg.lt);
        console2.log("                        user LTV: ", lens.getUserLTV(ISilo(collateralCfg.silo), user));

        fixedHelper.executeLiquidation({
            _flashLoanFrom: flashLoanFrom,
            _debtAsset: 0x29219dd400f2Bf60E5a23d13Be72B486D4038894,
            _maxDebtToCover: 89303938,
            _liquidation: liquidation,
            _dexSwapInput: dexSwapInput
        });
    }

    function _print(ISilo _silo, address _user) internal {
        ISiloConfig config = ISiloConfig(_silo.config());
        (
            ISiloConfig.ConfigData memory collateralCfg, ISiloConfig.ConfigData memory debtCfg
        ) = config.getConfigsForSolvency(_user);

        (address protected, address collateral, address debt) = config.getShareTokens(address(_silo));

        console2.log("collateral silo: ", collateralCfg.silo);
        console2.log("collateral silo asset: ", ISilo(collateralCfg.silo).asset());
        vm.label(collateralCfg.silo, "CollateralSilo");
        console2.log("debt silo: ", debtCfg.silo);
        console2.log("debt silo asset: ", ISilo(debtCfg.silo).asset());
        vm.label(debtCfg.silo, "DebtSilo");
        console2.log("collateral Liquidation Threshold: ", collateralCfg.lt);
        console2.log(".     debt Liquidation Threshold: ", debtCfg.lt);
        console2.log("                        user LTV: ", lens.getUserLTV(_silo, _user));
        console2.log("                    user solvent? ", _silo.isSolvent(_user) ? "YES" : "NO!");

        {
            uint256 collateralShares = IERC20(collateralCfg.silo).balanceOf(_user);
            uint256 protectedShares = IERC20(collateralCfg.protectedShareToken).balanceOf(_user);

            console2.log("collateral share balance: ", collateralShares);
            console2.log("collateral balance: ", ISilo(collateralCfg.silo).convertToAssets(collateralShares));

            console2.log(" protected share balance: ", protectedShares);
        }

        console2.log("debt share balance: ", IERC20(debtCfg.debtShareToken).balanceOf(_user));

        (
            uint256 collateralToLiquidate, uint256 debtToRepay, bool sTokenRequired, bool fullLiquidation
        ) = lens.maxLiquidation(ISilo(debtCfg.silo), IPartialLiquidation(debtCfg.hookReceiver), _user);

        console2.log("collateralToLiquidate: ", collateralToLiquidate);
        console2.log("debtToRepay: ", debtToRepay);
        console2.log("%s% to repay", debtToRepay * 100 / _silo.maxRepay(_user));
        console2.log("fullLiquidation: ", fullLiquidation ? "full" : "partial");

        console2.log("TOKENS_RECEIVER: ", manualHelper.TOKENS_RECEIVER());
        console2.log("collateralShareToken: ", IERC20(collateralCfg.collateralShareToken).balanceOf(manualHelper.TOKENS_RECEIVER()));
        console2.log("protectedShareToken: ", IERC20(collateralCfg.protectedShareToken).balanceOf(manualHelper.TOKENS_RECEIVER()));
    }
}
