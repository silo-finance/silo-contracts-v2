// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";

import {IERC20R} from "silo-core/contracts/interfaces/IERC20R.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IZeroExSwapModule} from "silo-core/contracts/interfaces/IZeroExSwapModule.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {SiloLeverageZeroEx, ISiloLeverageZeroEx} from "silo-core/contracts/leverage/SiloLeverageZeroEx.sol";

import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";
import {SwapRouterMock} from "./mocks/SwapRouterMock.sol";

/*
    FOUNDRY_PROFILE=core_test  forge test -vv --ffi --mc SiloLeverageTest
*/
contract SiloLeverageTest is SiloLittleHelper, Test {
    using SafeERC20 for IERC20;

    ISiloConfig cfg;
    SiloLeverageZeroEx siloLeverage;
    address collateralShareToken;
    address debtShareToken;
    SwapRouterMock swap;

    function setUp() public {
        cfg = _setUpLocalFixture();

        _deposit(1000e18, address(1));
        _depositForBorrow(2000e18, address(2));

        (,collateralShareToken,) = cfg.getShareTokens(address(silo0));
        (,, debtShareToken) = cfg.getShareTokens(address(silo1));

        siloLeverage = new SiloLeverageZeroEx(address(this));
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
        uint256 multiplier = 10;

        token0.mint(user, depositAmount);

        ISiloLeverageZeroEx.FlashArgs memory flashArgs = ISiloLeverageZeroEx.FlashArgs({
            amount: depositAmount * multiplier,
            token: silo1.asset(),
            flashloanTarget: address(silo1)
        });

        ISiloLeverageZeroEx.DepositArgs memory depositArgs = ISiloLeverageZeroEx.DepositArgs({
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

        // mock the swap
        swap.setSwap(token1, flashArgs.amount, token0, 1.3e18);

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
        uint256 finalMultiplier = totalDeposit * 1e18 / depositArgs.amount;

        assertEq(finalMultiplier, 14e18, "finalMultiplier 14x");
        assertEq(silo0.previewRedeem(silo0.balanceOf(user)), 1.4e18, "user got deposit x 10");
        assertEq(silo1.maxRepay(user), 1.0101e18, "user has debt equal to flashloan + fees");

        assertEq(token0.balanceOf(address(siloLeverage)), 0, "no token0");
        assertEq(token1.balanceOf(address(siloLeverage)), 0, "no token1");
        // TODO check debt approval to be 0

        // CLOSING LEVERAGE

        flashArgs = ISiloLeverageZeroEx.FlashArgs({
            amount: silo0.previewRedeem(silo0.balanceOf(user)),
            token: silo1.asset(),
            flashloanTarget: address(silo1)
        });

        ISiloLeverageZeroEx.CloseLeverageArgs memory args = ISiloLeverageZeroEx.CloseLeverageArgs({
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

        // mock the swap + 20%
        swap.setSwap(token0, flashArgs.amount, token1, flashArgs.amount * 1.2e18 / 1e18);

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

    // TODO nonReentrant

}
