// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";

import {IERC20R} from "silo-core/contracts/interfaces/IERC20R.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IZeroExSwapModule} from "silo-core/contracts/interfaces/IZeroExSwapModule.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ILeverageUsingSiloWithZeroEx} from "silo-core/contracts/interfaces/ILeverageUsingSiloWithZeroEx.sol";
import {LeverageUsingSiloWithZeroEx} from "silo-core/contracts/leverage/LeverageUsingSiloWithZeroEx.sol";

import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";
import {SwapRouterMock} from "./mocks/SwapRouterMock.sol";

/*
    FOUNDRY_PROFILE=core_test  forge test -vv --ffi --mc LeverageUsingSiloWithZeroExTest
*/
contract LeverageUsingSiloWithZeroExTest is SiloLittleHelper, Test {
    using SafeERC20 for IERC20;

    uint256 constant _PRECISION = 1e18;

    ISiloConfig cfg;
    LeverageUsingSiloWithZeroEx siloLeverage;
    address collateralShareToken;
    address debtShareToken;
    SwapRouterMock swap;

    function setUp() public {
        cfg = _setUpLocalFixture();

        _deposit(1000e18, address(1));
        _depositForBorrow(2000e18, address(2));

        (,collateralShareToken,) = cfg.getShareTokens(address(silo0));
        (,, debtShareToken) = cfg.getShareTokens(address(silo1));

        siloLeverage = new LeverageUsingSiloWithZeroEx(address(this));
        siloLeverage.setRevenueReceiver(makeAddr("RevenueReceiver"));
        siloLeverage.setLeverageFee(0.0001e18);

        swap = new SwapRouterMock();

        token0.setOnDemand(false);
        token1.setOnDemand(false);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_leverage_example
    */
    function test_leverage_example() public {
        address user = makeAddr("user");
        uint256 depositAmount = 0.1e18;
        uint256 multiplier = 1.08e18;

        token0.mint(user, depositAmount);

        ILeverageUsingSiloWithZeroEx.FlashArgs memory flashArgs = ILeverageUsingSiloWithZeroEx.FlashArgs({
            amount: depositAmount * multiplier / _PRECISION,
            token: silo1.asset(),
            flashloanTarget: address(silo1)
        });

        ILeverageUsingSiloWithZeroEx.DepositArgs memory depositArgs = ILeverageUsingSiloWithZeroEx.DepositArgs({
            amount: depositAmount,
            collateralType: ISilo.CollateralType.Collateral,
            silo: silo0
        });

        // this data should be provided by BE API
        // NOTICE: user needs to give allowance for swap router to use tokens
        IZeroExSwapModule.SwapArgs memory swapArgs = IZeroExSwapModule.SwapArgs({
            buyToken: address(silo0.asset()),
            sellToken: address(silo1.asset()),
            allowanceTarget: makeAddr("this is address provided by API"),
            exchangeProxy: address(swap),
            swapCallData: "mocked swap data"
        });

        // mock the swap: debt token -> collateral token, price is 1:1, lt's mock some fee
        swap.setSwap(token1, flashArgs.amount, token0, flashArgs.amount * 99 / 100);

        vm.startPrank(user);

        uint256 debtReceiveApproval = _calculateDebtReceiveApproval(
            flashArgs.amount, ISilo(flashArgs.flashloanTarget)
        );

        // APPROVALS

        // siloLeverage needs approval to pull user tokens to do deposit in behalf of user
        IERC20(depositArgs.silo.asset()).forceApprove(address(siloLeverage), depositArgs.amount);

        // user must set receive approval for debt share token
        IERC20R(debtShareToken).setReceiveApproval(address(siloLeverage), debtReceiveApproval);

        (uint256 totalDeposit, uint256 totalBorrow) = siloLeverage.openLeveragePosition(flashArgs, swapArgs, depositArgs);
        uint256 finalMultiplier = totalDeposit * _PRECISION / depositArgs.amount;

        assertEq(finalMultiplier, 2.06899308e18, "finalMultiplier");
        assertEq(silo0.previewRedeem(silo0.balanceOf(user)), 0.206899308e18, "users collateral");

        {
            uint256 flashFee = silo1.flashFee(address(token1), flashArgs.amount);

            assertEq(
                silo1.maxRepay(user),
                flashArgs.amount + flashFee,
                "user has debt equal to flashloan + flashloan fee"
            );
        }

        assertEq(silo1.maxRepay(user), 0.10908e18, "users debt");

        assertEq(token0.balanceOf(address(siloLeverage)), 0, "no token0");
        assertEq(token1.balanceOf(address(siloLeverage)), 0, "no token1");
        // TODO check debt approval to be 0

        // CLOSING LEVERAGE

        flashArgs = ILeverageUsingSiloWithZeroEx.FlashArgs({
            amount: silo0.previewRedeem(silo0.balanceOf(user)),
            token: silo1.asset(),
            flashloanTarget: address(silo1)
        });

        ILeverageUsingSiloWithZeroEx.CloseLeverageArgs memory args = ILeverageUsingSiloWithZeroEx.CloseLeverageArgs({
            siloWithCollateral: silo0,
            collateralType: ISilo.CollateralType.Collateral
        });

        swapArgs = IZeroExSwapModule.SwapArgs({
            sellToken: address(silo0.asset()),
            buyToken: address(silo1.asset()),
            allowanceTarget: makeAddr("this is address provided by API"),
            exchangeProxy: address(swap),
            swapCallData: "mocked swap data"
        });

        // mock the swap: part of collateral token -> debt token, so we can repay flashloan
        uint256 amountIn = flashArgs.amount * 102 / 100; // swap bit more so we can count for fee or slippage
        swap.setSwap(token0, amountIn, token1, flashArgs.amount * 99 / 100);

        // APPROVALS
        uint256 collateralSharesApproval = IERC20(collateralShareToken).balanceOf(user);
        IERC20(collateralShareToken).forceApprove(address(siloLeverage), collateralSharesApproval);

        siloLeverage.closeLeveragePosition(flashArgs, swapArgs, args);

        assertEq(silo0.balanceOf(user), 0, "user nas NO collateral");
        assertEq(silo1.maxRepay(user), 0, "user has NO debt");

        vm.stopPrank();
    }

    function _calculateDebtReceiveApproval(
        uint256 _flashAmount,
        ISilo _flashFrom
    ) internal view returns (uint256 debtReceiveApproval) {
        uint256 flashFee = _flashFrom.flashFee(_flashFrom.asset(), _flashAmount);
        uint256 leverageFee = siloLeverage.calculateLeverageFee(_flashAmount);

        debtReceiveApproval = _flashAmount + flashFee + leverageFee;
    }

    // TODO nonReentrant test

}
