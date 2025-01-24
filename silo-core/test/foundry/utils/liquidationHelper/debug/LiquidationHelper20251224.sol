// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {SiloLens} from "silo-core/contracts/SiloLens.sol";
import {ILiquidationHelper} from "silo-core/contracts/interfaces/ILiquidationHelper.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {LiquidationHelper} from "silo-core/contracts/utils/liquidationHelper/LiquidationHelper.sol";
import {PartialLiquidation} from "silo-core/contracts/utils/hook-receivers/liquidation/PartialLiquidation.sol";

/*
 FOUNDRY_PROFILE=core-test forge test --ffi --mc LiquidationHelper20251224 -vv

 https://sonicscan.org/tx/0xc38d42eefd0c4be29cd64c68ec362aacf8d5bb2de37a24a342bb5c34efc2b6be

 executeLiquidation(address, address, uint256, (address,address,address), (address,address,bytes)[])
#	Name	Type	Data
1	_flashLoanFrom	address	0x4E216C15697C1392fE59e1014B009505E05810Df
2	_debtAsset	address	0x29219dd400f2Bf60E5a23d13Be72B486D4038894
3	_maxDebtToCover	uint256
6780883
3	_liquidation.hook	address	0xB01e62Ba9BEc9Cfa24b2Ee321392b8Ce726D2A09
3	_liquidation.collateralAsset	address	0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38
3	_liquidation.user	address	0x1563C4751Ad2be48Fd17464B73585B6ba8b6A5f0
4	_swapsInputs0x.sellToken	address	0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38
4	_swapsInputs0x.allowanceTarget	address	0xaC041Df48dF9791B0654f1Dbbf2CC8450C5f2e9D
4	_swapsInputs0x.swapCallData	bytes
0x83bd37f90001039e2fb66102314ce7b64ce5ce3e5183bc94ad38000129219dd400f2bf60e5a23d13be72b486d403889408af057eed245c8fc2036df19007ae1400019b99e9c620b2e2f09e0b9fced8f679eecf2653fe0001dc85f86d5e3189e0d4a776e6ae3b3911ec7b01330001
0665609124cc2a958cf0ed582ee132076243b6da
0000000003010203000301010001020119ff00000000000000000000000000000000000000dc85f86d5e3189e0d4a776e6ae3b3911ec7b0133039e2fb66102314ce7b64ce5ce3e5183bc94ad38000000000000000000000000000000000000000000000000

*/
contract LiquidationHelper20251224 is Test {
    address payable public constant REWARD_COLLECTOR = payable(address(123456789));

    function setUp() public {
        uint256 blockToFork = 5132364 - 1;
        vm.createSelectFork(vm.envString("RPC_SONIC"), blockToFork);
    }

    /*
         TODO this can must be skip because foundry do not support Sonic network yet
    */
    function test_skip_debug_liquidationCall() public {
        SiloLens lens = new SiloLens();

        LiquidationHelper liquidationHelper = LiquidationHelper(payable(0xf363C6d369888F5367e9f1aD7b6a7dAe133e8740));
        address hookReceiver = 0xB01e62Ba9BEc9Cfa24b2Ee321392b8Ce726D2A09;
        address borrower = 0x1563C4751Ad2be48Fd17464B73585B6ba8b6A5f0;
        ISilo flashLoanFrom = ISilo(0x4E216C15697C1392fE59e1014B009505E05810Df);
        PartialLiquidation liquidation = PartialLiquidation(hookReceiver);

        ISiloConfig siloConfig = liquidation.siloConfig();
        (, ISiloConfig.ConfigData memory debtConfig) = siloConfig.getConfigsForSolvency(borrower);

        emit log_named_string("solvent?", ISilo(debtConfig.silo).isSolvent(borrower) ? "yes" : "NO");
        emit log_named_decimal_uint("getLtv", lens.getLtv(ISilo(debtConfig.silo), borrower), 16);

        (uint256 collateral, uint256 debtToRepay,) = liquidation.maxLiquidation(borrower);
        emit log_named_decimal_uint("collateral", collateral, 18);
        emit log_named_decimal_uint("debtToRepay", debtToRepay, 18);

        _executeLiquidation(hookReceiver, flashLoanFrom, liquidationHelper);
    }

    function _executeLiquidation(
        address hookReceiver,
        ISilo flashLoanFrom,
        LiquidationHelper liquidationHelper
    ) internal {
        uint256 collateralToLiquidate = 12611625888503336898;

        /*
        0x83bd37f90001039e2fb66102314ce7b64ce5ce3e5183bc94ad38000129219dd400f2bf60e5a23d13be72b486d403889408af057eed245c8fc2036df19007ae1400019b99e9c620b2E2f09E0b9Fced8F679eEcF2653FE0001dc85F86d5E3189e0d4a776e6Ae3B3911eC7B013300010665609124CC2a958Cf0ED582eE132076243B6Da0000000003010203000301010001020119ff00000000000000000000000000000000000000dc85f86d5e3189e0d4a776e6ae3b3911ec7b0133039e2fb66102314ce7b64ce5ce3e5183bc94ad38000000000000000000000000000000000000000000000000
        */
        bytes memory swapCallData = abi.encodePacked(
            hex"83bd37f90001039e2fb66102314ce7b64ce5ce3e5183bc94ad38000129219dd400f2bf60e5a23d13be72b486d403889408af057eed245c8fc2036df19007ae1400019b99e9c620b2e2f09e0b9fced8f679eecf2653fe0001dc85f86d5e3189e0d4a776e6ae3b3911ec7b01330001",
            address(liquidationHelper), // seller address in swap data
            hex"0000000003010203000301010001020119ff00000000000000000000000000000000000000dc85f86d5e3189e0d4a776e6ae3b3911ec7b0133039e2fb66102314ce7b64ce5ce3e5183bc94ad38000000000000000000000000000000000000000000000000"
        );

        ILiquidationHelper.DexSwapInput[] memory swapsInputs0x = new ILiquidationHelper.DexSwapInput[](1);
        swapsInputs0x[0].sellToken = 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38;
        swapsInputs0x[0].allowanceTarget = 0xaC041Df48dF9791B0654f1Dbbf2CC8450C5f2e9D;
        swapsInputs0x[0].swapCallData = swapCallData;

        ILiquidationHelper.LiquidationData memory liquidation;
        liquidation.hook = IPartialLiquidation(hookReceiver);
        liquidation.collateralAsset = 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38;
        liquidation.user = 0x1563C4751Ad2be48Fd17464B73585B6ba8b6A5f0;

        address debtToken = 0x29219dd400f2Bf60E5a23d13Be72B486D4038894;
        uint256 debtToCover = 6780883;

        liquidationHelper.executeLiquidation(
            flashLoanFrom,
            debtToken,
            debtToCover,
            liquidation,
            swapsInputs0x
        );
    }
}
