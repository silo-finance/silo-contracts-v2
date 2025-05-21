// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {IERC20R} from "silo-core/contracts/interfaces/IERC20R.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IZeroExSwapModule} from "silo-core/contracts/interfaces/IZeroExSwapModule.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {SiloLeverage, ISiloLeverage} from "silo-core/contracts/leverage/SiloLeverage.sol";

import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";
import {SwapRouterMock} from "./mocks/SwapRouterMock.sol";

/*
    FOUNDRY_PROFILE=core_test  forge test -vv --ffi --mc SiloLeverageTest
*/
contract SiloLeverageTest is SiloLittleHelper, Test {
    ISiloConfig cfg;
    SiloLeverage siloLeverage;
    address debtShareToken;
    SwapRouterMock swap;

    function setUp() public {
        cfg = _setUpLocalFixture();

        token0.setOnDemand(true);
        token1.setOnDemand(true);

        _deposit(1000e18, address(1));
        _depositForBorrow(2000e18, address(2));

        (,, debtShareToken) = cfg.getShareTokens(address(silo1));

        siloLeverage = new SiloLeverage(address(this));
        swap = new SwapRouterMock();
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_leverage_example
    */
    function test_leverage_example() public {
        address user = makeAddr("user");
        uint256 depositAmount = 0.1e18;
        uint256 multiplier = 10;


        ISiloLeverage.FlashArgs memory flashArgs = ISiloLeverage.FlashArgs({
            amount: depositAmount * multiplier,
            token: silo1.asset(),
            flashDebtLender: address(silo1)
        });

        ISiloLeverage.DepositArgs memory depositArgs = ISiloLeverage.DepositArgs({
            amount: depositAmount,
            receiver: user,
            collateralType: ISilo.CollateralType.Collateral,
            silo: silo0
        });

        // this data should be provided by BE API
        IZeroExSwapModule.SwapArgs memory swapArgs = IZeroExSwapModule.SwapArgs({
            buyToken: address(silo0.asset()),
            sellToken: address(silo1.asset()),
            allowanceTarget: makeAddr("this is address provided by API"),
            exchangeProxy: address(swap),
            swapCallData: "mocked swap data"
        });

        // we required to provide this
        ISilo borrowSilo = silo1;

        // mock the swap
        swap.setSwap(token1, flashArgs.amount, token0, 1.3e18);

        vm.startPrank(user);

        IERC20R(debtShareToken).setReceiveApproval(address(siloLeverage), 2e18);
        uint256 finalMultiplier = siloLeverage.leverage(flashArgs, swapArgs, depositArgs, borrowSilo);
        IERC20R(debtShareToken).setReceiveApproval(address(siloLeverage), 0);

        vm.stopPrank();

        assertEq(finalMultiplier, 1.4e18, "finalMultiplier");
        assertEq(silo0.previewRedeem(silo0.balanceOf(user)), 1.4e18, "user got deposit x 10");
        assertEq(silo1.maxRepay(user), 1.01e18, "user has debt equal to flashloan + fees");
    }
}
