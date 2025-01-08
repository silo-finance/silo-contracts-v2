// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {SiloLens} from "silo-core/contracts/SiloLens.sol";
import {ILiquidationHelper} from "silo-core/contracts/interfaces/ILiquidationHelper.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {LiquidationHelper} from "silo-core/contracts/utils/liquidationHelper/LiquidationHelper.sol";

import {SiloConfigOverride} from "../../_common/fixtures/SiloFixture.sol";
import {SiloFixtureWithVeSilo as SiloFixture} from "../../_common/fixtures/SiloFixtureWithVeSilo.sol";

import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";
import {MintableToken} from "../../_common/MintableToken.sol";

/*
 forge test --ffi --gas-price 1 -vv --mc LiquidationHelperOdosTest
*/
contract LiquidationHelperOdosTest is SiloLittleHelper, Test {
    LiquidationHelper liquidationHelper;
    SiloLens lens;
    ISilo flashLoanFrom;
    address hookReceiver;

    address payable public constant REWARD_COLLECTOR = payable(address(123456789));
    address public constant ODOS_ROUTER = address(0xaC041Df48dF9791B0654f1Dbbf2CC8450C5f2e9D);
    address public constant ODOS_WS = address(0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38);
    address public constant ODOS_WETH = address(0x50c42dEAcD8Fc9773493ED674b675bE577f2634b);

    function setUp() public {
        uint256 blockToFork = 2838462;
        vm.createSelectFork(vm.envString("RPC_SONIC"), blockToFork);

        SiloFixture siloFixture = new SiloFixture();

        SiloConfigOverride memory configOverride;
        configOverride.token0 = ODOS_WS;
        configOverride.token1 = ODOS_WETH;
        configOverride.configName = "stS_S_Silo";

        (, silo0, silo1,,,hookReceiver ) = siloFixture.deploy_local(configOverride);

        vm.label(address(silo0), "silo0");
        vm.label(address(silo1), "silo1");

        token0 = MintableToken(ODOS_WS);
        token1 = MintableToken(ODOS_WETH);

        vm.label(address(token0), "wS");
        vm.label(address(token1), "WETH");

        liquidationHelper = new LiquidationHelper(ODOS_WS, ODOS_ROUTER, REWARD_COLLECTOR);
        lens = new SiloLens();

        // another deployment so we have silo for flashloan
        (,, flashLoanFrom,,,) = siloFixture.deploy_local(configOverride);
        vm.label(address(flashLoanFrom), "flashLoanFrom");
    }

    function test_skip_odos_liquidationCall() public {
//        _createPositionToliquidate(block.timestamp + 5 days + 15 hours); UnableToRepayFlashloan
//        _createPositionToliquidate(block.timestamp + 3 days + 18 hours);
        _createPositionToliquidate(block.timestamp + 5 days + 10 hours);

        address borrower = makeAddr("borrower");

        emit log_named_decimal_uint("getLtv", lens.getLtv(silo1, borrower), 16);
        emit log_named_decimal_uint("maxRepay", silo1.maxRepay(borrower), 18);
        assertFalse(silo1.isSolvent(borrower), "user should be insolvent");
        assertLt(lens.getLtv(silo1, borrower), 0.98e18, "we want healthy position");

        (uint256 collateralToLiquidate, uint256 debtToRepay,) = IPartialLiquidation(hookReceiver).maxLiquidation(borrower);
        assertLt(collateralToLiquidate, 50e18, "we want FULL");

        // 0x83bd37f90001039e2fb66102314ce7b64ce5ce3e5183bc94ad380001e5da20f15420ad15de0fa650600afc998bbe39550902b5e3af16b18800000902b3adcbddd3780000028f5c00019b99e9c620b2E2f09E0b9Fced8F679eEcF2653FE00000001
        // 7a111C75EfE7C6A05991514E4363531a143521E9
        // 00000000030102040163ba393b06010101020100060101030201ff0000000000000000000066def9ad68accb63d4c96dc13cb7a7f9d5e03ae5039e2fb66102314ce7b64ce5ce3e5183bc94ad3825a317bde2f9d0bf5f1c0d3c432d99f476d6ae5a00000000
        // SWAP sW => WETH
        bytes memory swapCallData = abi.encodePacked(
            hex"83bd37f90001039e2fb66102314ce7b64ce5ce3e5183bc94ad38000150c42deacd8fc9773493ed674b675be577f2634b09",
//            hex"02b5e3af16b1880000", // amount in
            uint72(collateralToLiquidate), // amount in
            hex"07257ed11a78e51e028f5c00018e7591e2919157A6BBE9E3defe0F1Ff793e65Ec100000001",
            address(liquidationHelper), // seller address in swap data
            hex"000000000301020300060101010201ff000000000000000000000000000000000000000000e45a270b10cfed62ba586d3f1b72b36989a623ba039e2fb66102314ce7b64ce5ce3e5183bc94ad38000000000000000000000000000000000000000000000000"
        );

        ILiquidationHelper.DexSwapInput[] memory swapsInputs0x = new ILiquidationHelper.DexSwapInput[](1);
        swapsInputs0x[0].sellToken = ODOS_WS;
        swapsInputs0x[0].allowanceTarget = ODOS_ROUTER;
        swapsInputs0x[0].swapCallData = swapCallData;

        ILiquidationHelper.LiquidationData memory liquidation;
        liquidation.hook = IPartialLiquidation(hookReceiver);
        liquidation.collateralAsset = ODOS_WS;
        liquidation.user = borrower;

        assertEq(IERC20(ODOS_WETH).balanceOf(REWARD_COLLECTOR), 0, "empty wallet before liquidation");

        (uint256 withdrawCollateral, uint256 repayDebtAssets) = liquidationHelper.executeLiquidation(
            flashLoanFrom,
            ODOS_WETH,
            silo1.maxRepay(borrower),
            liquidation,
            swapsInputs0x
        );

        assertEq(lens.getLtv(silo1, borrower), 0, "user should be fully liquidated");
        assertEq(IERC20(ODOS_WETH).balanceOf(REWARD_COLLECTOR), 1, "got profit");


//        assertEq(buyToken.balanceOf(address(dex)), 10535913188180254, "expect to have WETH");
//        assertEq(sellToken.allowance(address(dex), allowanceTarget), 0, "allowance should be reset to 0");
    }

    function _createPositionToliquidate(uint256 _jumpTime) internal {
        address wsWhale = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
        address wethWhale = 0x58AaAa07AB256147d53FB0C9223be827EE11db03;

        // deposit wS, borrow WETH
        address borrower = makeAddr("borrower");
        address depositor = makeAddr("depositor");
        uint256 assets = 50e18;
        uint256 deposit = 37.5e18;

        IERC20 sellToken = IERC20(ODOS_WS);
        IERC20 buyToken = IERC20(ODOS_WETH);

        vm.prank(wsWhale);
        IERC20(ODOS_WS).transfer(borrower,assets);

        vm.prank(wethWhale);
        IERC20(ODOS_WETH).transfer(depositor,deposit);

        vm.startPrank(depositor);
        IERC20(ODOS_WETH).approve(address(silo1), deposit);
        silo1.deposit(deposit, depositor, ISilo.CollateralType.Collateral);
        vm.stopPrank();

        vm.startPrank(borrower);
        IERC20(ODOS_WS).approve(address(silo0), assets);
        silo0.deposit(assets, borrower, ISilo.CollateralType.Collateral);

        emit log_named_decimal_uint("maxBorrow", silo1.maxBorrow(borrower), 18);

        silo1.borrow(silo1.maxBorrow(borrower), borrower, borrower);
//        silo0.withdraw(silo0.maxWithdraw(borrower), borrower, borrower, ISilo.CollateralType.Collateral);
        vm.stopPrank();

        vm.warp(_jumpTime);

        uint256 amountToRepay = silo1.maxRepay(borrower);
        amountToRepay += flashLoanFrom.flashFee(ODOS_WETH, amountToRepay);
        emit log_named_decimal_uint("maxRepay", amountToRepay, 18);

        vm.prank(wethWhale);
        IERC20(ODOS_WETH).transfer(depositor,amountToRepay);

        vm.startPrank(depositor);
        IERC20(ODOS_WETH).approve(address(flashLoanFrom), amountToRepay);
        flashLoanFrom.deposit(amountToRepay , depositor, ISilo.CollateralType.Collateral);
        vm.stopPrank();
    }
}
