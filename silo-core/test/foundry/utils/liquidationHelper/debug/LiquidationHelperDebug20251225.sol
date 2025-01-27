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
 FOUNDRY_PROFILE=core-test forge test --ffi --mc LiquidationHelper20251225 -vv

https://sonicscan.org/tx/0xf3710143176fe0653979c9405f7be60a7c335f1a73f181ef6337c9e826dfb833

executeLiquidation(address, address, uint256, (address,address,address), (address,address,bytes)[])
#	Name	Type	Data
1	_flashLoanFrom	address	0x4E216C15697C1392fE59e1014B009505E05810Df
2	_debtAsset	address	0x29219dd400f2Bf60E5a23d13Be72B486D4038894
3	_maxDebtToCover	uint256
35317191
3	_liquidation.hook	address	0xB01e62Ba9BEc9Cfa24b2Ee321392b8Ce726D2A09
3	_liquidation.collateralAsset	address	0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38
3	_liquidation.user	address	0xe11e9e091E612BAd0c7EF9b8eea5E43093946088
4	_swapsInputs0x.sellToken	address	0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38
4	_swapsInputs0x.allowanceTarget	address	0xaC041Df48dF9791B0654f1Dbbf2CC8450C5f2e9D
4	_swapsInputs0x.swapCallData	bytes
0x83bd37f90001039e2fb66102314ce7b64ce5ce3e5183bc94ad38000129219dd400f2bf60e5a23d13be72b486d40388940903e2080a856a3d30a504023ee3aa07ae1400019b99e9c620b2e2f09e0b9fced8f679eecf2653fe00000001f363c6d369888f5367e9f1ad7b6a7dae133e8740000000000d080509016ec6927f0601000102010167bba495060200030201000603010402010541dddba600000596e47ce8070400050632bac522c4f97f4913d18d81cf3be119c8cce26a00010000000000000000005004070400050661047ca44865982bac5dc9b7f100247376d74b67000100000000000000000086020704000706c5ab8d98f959453e416b2f15848a02cc99bc695e000200000000000000000022000703010508df49944d79b4032e244063ebfe413a3179d6b2e7000100000000000000000084080703010608cd4d2b142235d5650ffa6a38787ed0b7d7a51c0c000000000000000000000037ff00000000000000000000000000000000000000000000b8bda81eccb1a21198899ac8f1f2f73c82bd7695039e2fb66102314ce7b64ce5ce3e5183bc94ad3825a317bde2f9d0bf5f1c0d3c432d99f476d6ae5a48505b3047d5c2af657037034369700f4d036822e5da20f15420ad15de0fa650600afc998bbe3955d3dce716f3ef535c5ff8d041c1a41c3bd89b97aee51ee9868c1f0d6cd968a8b8c8376dc2991bfe4429219dd400f2bf60e5a23d13be72b486d4038894

*/
contract LiquidationHelper20251225 is Test {
    address payable public constant REWARD_COLLECTOR = payable(address(123456789));

    function setUp() public {
        uint256 blockToFork = 5320801 - 1;
        vm.createSelectFork(vm.envString("RPC_SONIC"), blockToFork);
    }

    /*
         TODO this can must be skip because foundry do not support Sonic network yet
    */
    function test_skip_debug_liquidationCall() public {
        SiloLens lens = new SiloLens();

        LiquidationHelper liquidationHelper = LiquidationHelper(payable(0xf363C6d369888F5367e9f1aD7b6a7dAe133e8740));

        liquidationHelper = new LiquidationHelper(
            0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38,
            0xaC041Df48dF9791B0654f1Dbbf2CC8450C5f2e9D,
            payable(makeAddr("TOKENS_RECEIVER"))
        );

        address hookReceiver = 0xB01e62Ba9BEc9Cfa24b2Ee321392b8Ce726D2A09;
        address borrower = 0xe11e9e091E612BAd0c7EF9b8eea5E43093946088;

        ISilo flashLoanFrom = ISilo(0x4E216C15697C1392fE59e1014B009505E05810Df);
        PartialLiquidation liquidation = PartialLiquidation(hookReceiver);

        vm.label(address(liquidationHelper), "LiquidationHelper");
        ISiloConfig siloConfig = liquidation.siloConfig();
        (, ISiloConfig.ConfigData memory debtConfig) = siloConfig.getConfigsForSolvency(borrower);

        emit log_named_string("solvent?", ISilo(debtConfig.silo).isSolvent(borrower) ? "yes" : "NO");
        uint256 ltv = lens.getLtv(ISilo(debtConfig.silo), borrower);
        emit log_named_decimal_uint("getLtv", ltv, 16);
        emit log_named_address("user", borrower);
        emit log_named_address("silo", address(debtConfig.silo));

        (uint256 collateral, uint256 debtToRepay,) = liquidation.maxLiquidation(borrower);
        emit log_named_decimal_uint("collateral", collateral, 18);
        emit log_named_decimal_uint("debtToRepay", debtToRepay, 6);

//        if (ltv >= 1e18) revert("bad debt");
        _executeLiquidation(borrower, hookReceiver, flashLoanFrom, liquidationHelper);
    }

    function _executeLiquidation(
        address borrower,
        address hookReceiver,
        ISilo flashLoanFrom,
        LiquidationHelper liquidationHelper
    ) internal {
        uint256 collateralToLiquidate = 71627511841643376805;
        /*
        83bd37f90001039e2fb66102314ce7b64ce5ce3e5183bc94ad38000129219dd400f2bf60e5a23d13be72b486d403889409
        03e2080a856a3d30a5
        04023ee3aa07ae1400019b99e9c620b2e2f09e0b9fced8f679eecf2653fe00000001
        f363c6d369888f5367e9f1ad7b6a7dae133e8740
        000000000d080509016ec6927f0601000102010167bba495060200030201000603010402010541dddba600000596e47ce8070400050632bac522c4f97f4913d18d81cf3be119c8cce26a00010000000000000000005004070400050661047ca44865982bac5dc9b7f100247376d74b67000100000000000000000086020704000706c5ab8d98f959453e416b2f15848a02cc99bc695e000200000000000000000022000703010508df49944d79b4032e244063ebfe413a3179d6b2e7000100000000000000000084080703010608cd4d2b142235d5650ffa6a38787ed0b7d7a51c0c000000000000000000000037ff00000000000000000000000000000000000000000000b8bda81eccb1a21198899ac8f1f2f73c82bd7695039e2fb66102314ce7b64ce5ce3e5183bc94ad3825a317bde2f9d0bf5f1c0d3c432d99f476d6ae5a48505b3047d5c2af657037034369700f4d036822e5da20f15420ad15de0fa650600afc998bbe3955d3dce716f3ef535c5ff8d041c1a41c3bd89b97aee51ee9868c1f0d6cd968a8b8c8376dc2991bfe4429219dd400f2bf60e5a23d13be72b486d4038894

        */
        bytes memory swapCallData = abi.encodePacked(
            hex"83bd37f90001039e2fb66102314ce7b64ce5ce3e5183bc94ad38000129219dd400f2bf60e5a23d13be72b486d403889408",
            uint72(collateralToLiquidate), // amount in, 18 characters
            hex"04023ee3aa07ae1400019b99e9c620b2e2f09e0b9fced8f679eecf2653fe00000001",
            address(liquidationHelper), // seller address in swap data
            hex"000000000d080509016ec6927f0601000102010167bba495060200030201000603010402010541dddba600000596e47ce8070400050632bac522c4f97f4913d18d81cf3be119c8cce26a00010000000000000000005004070400050661047ca44865982bac5dc9b7f100247376d74b67000100000000000000000086020704000706c5ab8d98f959453e416b2f15848a02cc99bc695e000200000000000000000022000703010508df49944d79b4032e244063ebfe413a3179d6b2e7000100000000000000000084080703010608cd4d2b142235d5650ffa6a38787ed0b7d7a51c0c000000000000000000000037ff00000000000000000000000000000000000000000000b8bda81eccb1a21198899ac8f1f2f73c82bd7695039e2fb66102314ce7b64ce5ce3e5183bc94ad3825a317bde2f9d0bf5f1c0d3c432d99f476d6ae5a48505b3047d5c2af657037034369700f4d036822e5da20f15420ad15de0fa650600afc998bbe3955d3dce716f3ef535c5ff8d041c1a41c3bd89b97aee51ee9868c1f0d6cd968a8b8c8376dc2991bfe4429219dd400f2bf60e5a23d13be72b486d4038894"
        );

        ILiquidationHelper.DexSwapInput[] memory swapsInputs0x = new ILiquidationHelper.DexSwapInput[](1);
        swapsInputs0x[0].sellToken = 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38;
        swapsInputs0x[0].allowanceTarget = 0xaC041Df48dF9791B0654f1Dbbf2CC8450C5f2e9D;
        swapsInputs0x[0].swapCallData = swapCallData;

        vm.label(swapsInputs0x[0].allowanceTarget, "allowanceTarget");

        ILiquidationHelper.LiquidationData memory liquidation;
        liquidation.hook = IPartialLiquidation(hookReceiver);
        liquidation.collateralAsset = 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38;
        liquidation.user = borrower;

        address debtToken = 0x29219dd400f2Bf60E5a23d13Be72B486D4038894;
        vm.label(debtToken, "debtToken");
        vm.label(liquidation.collateralAsset, "collateralAsset");
        uint256 debtToCover = 35317191;

        liquidationHelper.executeLiquidation(
            flashLoanFrom,
            debtToken,
            debtToCover,
            liquidation,
            swapsInputs0x
        );
    }
}
