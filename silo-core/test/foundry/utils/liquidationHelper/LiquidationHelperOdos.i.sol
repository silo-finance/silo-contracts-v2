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

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);

    function description() external view returns (string memory);

    function version() external view returns (uint256);
    function latestAnswer() external view returns (uint256);

    function getRoundData(uint80 _roundId)
    external
    view
    returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );

    function latestRoundData()
    external
    view
    returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
}

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
    address public constant ODOS_STS = address(0xE5DA20F15420aD15DE0fa650600aFc998bbE3955);
    address public constant ODOS_WS = address(0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38);

    function setUp() public {
        uint256 blockToFork = 3087867;
        vm.createSelectFork(vm.envString("RPC_SONIC"), blockToFork);

        SiloFixture siloFixture = new SiloFixture();

        SiloConfigOverride memory configOverride;
        configOverride.token0 = ODOS_STS;
        configOverride.token1 = ODOS_WS;
        configOverride.configName = "stS_S_Silo";

        (, silo0, silo1,,,hookReceiver ) = siloFixture.deploy_local(configOverride);

        vm.label(address(silo0), "silo0");
        vm.label(address(silo1), "silo1");

        token0 = MintableToken(ODOS_STS);
        token1 = MintableToken(ODOS_WS);

        vm.label(address(token0), "wS");
        vm.label(address(token1), "stS");

        liquidationHelper = new LiquidationHelper(ODOS_WS, ODOS_ROUTER, REWARD_COLLECTOR);
        lens = new SiloLens();

        // another deployment so we have silo for flashloan
        (,, flashLoanFrom,,,) = siloFixture.deploy_local(configOverride);
        vm.label(address(flashLoanFrom), "flashLoanFrom");
    }

    function test_odos_liquidationCall_partial() public {
        uint256 jump = 1;

        _createPositionToliquidate(block.timestamp + jump);
        _mockOracleCall(false, jump);

        address borrower = makeAddr("borrower");

        emit log_named_decimal_uint("getLtv", lens.getLtv(silo1, borrower), 16);

        assertFalse(silo1.isSolvent(borrower), "user should be insolvent");
        assertLt(lens.getLtv(silo1, borrower), 0.98e18, "we want healthy position");

        (uint256 collateralToLiquidate, uint256 debtToRepay,) = IPartialLiquidation(hookReceiver).maxLiquidation(borrower);
        assertLt(collateralToLiquidate, 50e18, "we want FULL");

        // note: this is swap data for stS => sW with 50% slippage allowance
        bytes memory swapCallData = abi.encodePacked(
            hex"83bd37f90001e5da20f15420ad15de0fa650600afc998bbe39550001039e2fb66102314ce7b64ce5ce3e5183bc94ad3809",
            uint72(collateralToLiquidate), // amount in
            hex"0902b7ffaaafdba980007fffff00019b99e9c620b2E2f09E0b9Fced8F679eEcF2653FE00000001",
            address(liquidationHelper), // seller address in swap data
            hex"000000000301020300060101010200ff000000000000000000000000000000000000000000de861c8fc9ab78fe00490c5a38813d26e2d09c95e5da20f15420ad15de0fa650600afc998bbe3955000000000000000000000000000000000000000000000000"
        );

        ILiquidationHelper.DexSwapInput[] memory swapsInputs0x = new ILiquidationHelper.DexSwapInput[](1);
        swapsInputs0x[0].sellToken = ODOS_STS;
        swapsInputs0x[0].allowanceTarget = ODOS_ROUTER;
        swapsInputs0x[0].swapCallData = swapCallData;

        ILiquidationHelper.LiquidationData memory liquidation;
        liquidation.hook = IPartialLiquidation(hookReceiver);
        liquidation.collateralAsset = ODOS_STS;
        liquidation.user = borrower;

        assertEq(IERC20(ODOS_WS).balanceOf(REWARD_COLLECTOR), 0, "empty wallet before liquidation");

        (uint256 withdrawCollateral, uint256 repayDebtAssets) = liquidationHelper.executeLiquidation(
            flashLoanFrom,
            ODOS_WS,
            silo1.maxRepay(borrower),
            liquidation,
            swapsInputs0x
        );

        vm.clearMockedCalls();

        assertLe(lens.getLtv(silo1, borrower), 0.95e18, "user should be partially liquidated");
        assertTrue(silo1.isSolvent(borrower), "user should be solvent");

        assertEq(IERC20(ODOS_WS).balanceOf(REWARD_COLLECTOR), 1, "got profit");


//        assertEq(buyToken.balanceOf(address(dex)), 10535913188180254, "expect to have WETH");
//        assertEq(sellToken.allowance(address(dex), allowanceTarget), 0, "allowance should be reset to 0");
    }

    function _mockOracleCall(bool _priceCrash, uint256 _timeJump) internal {
        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = AggregatorV3Interface(0x65d0F14f7809CdC4f90c3978c753C4671b6B815b).latestRoundData();

        answer = _priceCrash ? answer / 10 : answer * 9995 / 10000;

        vm.mockCall(
            0xb4fe9028A4D4D8B3d00e52341F2BB0798860532C,
            abi.encodePacked(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(roundId, answer, startedAt, uint256(block.timestamp + _timeJump), answeredInRound)
        );
    }

    function _createPositionToliquidate(uint256 _jumpTime) internal {
        address stsWhale = 0xBB435A52EC1ED3945a636A8f0058ea3CB1e027E8;
        address wsWhale = 0x92928Fe008Ed635aA822A5CAdf0Cba340D754A66;
        vm.label(stsWhale, "stsWhale");
        vm.label(wsWhale, "wsWhale");

        // deposit wS, borrow WETH
        address borrower = makeAddr("borrower");
        address depositor = makeAddr("depositor");
        uint256 assets = 50e18;
        uint256 deposit = 37.5e18;

        vm.prank(stsWhale);
        IERC20(ODOS_STS).transfer(borrower,assets);

        vm.prank(wsWhale);
        IERC20(ODOS_WS).transfer(depositor,deposit);

        vm.startPrank(depositor);
        IERC20(ODOS_WS).approve(address(silo1), deposit);
        silo1.deposit(deposit, depositor, ISilo.CollateralType.Collateral);
        vm.stopPrank();

        vm.startPrank(borrower);
        IERC20(ODOS_STS).approve(address(silo0), assets);
        silo0.deposit(assets, borrower, ISilo.CollateralType.Collateral);

        emit log_named_decimal_uint("maxBorrow", silo1.maxBorrow(borrower), 18);

        silo1.borrow(silo1.maxBorrow(borrower), borrower, borrower);
        silo0.withdraw(silo0.maxWithdraw(borrower), borrower, borrower, ISilo.CollateralType.Collateral);
        vm.stopPrank();

        vm.warp(_jumpTime);

        uint256 amountToRepay = silo1.maxRepay(borrower);
        amountToRepay += flashLoanFrom.flashFee(ODOS_WS, amountToRepay);
        emit log_named_decimal_uint("repay + flash fee", amountToRepay, 18);

        vm.prank(wsWhale);
        IERC20(ODOS_WS).transfer(depositor,amountToRepay);

        vm.startPrank(depositor);
        IERC20(ODOS_WS).approve(address(flashLoanFrom), amountToRepay);
        flashLoanFrom.deposit(amountToRepay , depositor, ISilo.CollateralType.Collateral);
        vm.stopPrank();
    }
}
