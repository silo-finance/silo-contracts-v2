// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {
    LeverageUsingSiloFlashloanWithGeneralSwap
} from "silo-core/contracts/leverage/LeverageUsingSiloFlashloanWithGeneralSwap.sol";
import {ILeverageUsingSiloFlashloan} from "silo-core/contracts/interfaces/ILeverageUsingSiloFlashloan.sol";
import {ILeverageUsingSiloFlashloan} from "silo-core/contracts/interfaces/ILeverageUsingSiloFlashloan.sol";
import {IGeneralSwapModule} from "silo-core/contracts/interfaces/IGeneralSwapModule.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ICrossReentrancyGuard} from "silo-core/contracts/interfaces/ICrossReentrancyGuard.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";
import {TransientReentrancy} from "silo-core/contracts/hooks/_common/TransientReentrancy.sol";

import {OpenLeveragePositionReentrancyTest} from "./OpenLeveragePositionReentrancyTest.sol";

contract CloseLeveragePositionReentrancyTest is OpenLeveragePositionReentrancyTest {
    function callMethod() external override {
        _openLeverage();
        _closeLeverage();
    }

    function verifyReentrancy() external override {
        emit log_string("[CloseLeveragePositionReentrancyTest] before closeLeveragePosition");
        LeverageUsingSiloFlashloanWithGeneralSwap leverage = _getLeverage();
        
        bytes memory swapArgs = "";
        
        ILeverageUsingSiloFlashloan.CloseLeverageArgs memory closeArgs = ILeverageUsingSiloFlashloan.CloseLeverageArgs({
            flashloanTarget: address(TestStateLib.silo1()),
            siloWithCollateral: TestStateLib.silo0(),
            collateralType: ISilo.CollateralType.Collateral
        });
        
        vm.expectRevert(TransientReentrancy.ReentrancyGuardReentrantCall.selector);
        leverage.closeLeveragePosition(swapArgs, closeArgs);
    }

    function methodDescription() external pure override returns (string memory description) {
        description = "closeLeveragePosition(bytes,(address,address,uint8))";
    }

    function _closeLeverage() internal {
        address user = makeAddr("User");

        ILeverageUsingSiloFlashloan.CloseLeverageArgs memory closeArgs = ILeverageUsingSiloFlashloan.CloseLeverageArgs({
            flashloanTarget: address(TestStateLib.silo1()),
            siloWithCollateral: TestStateLib.silo0(),
            collateralType: ISilo.CollateralType.Collateral
        });

        IGeneralSwapModule.SwapArgs memory swapArgs = IGeneralSwapModule.SwapArgs({
            sellToken: TestStateLib.token0(),
            buyToken: TestStateLib.token1(),
            allowanceTarget: address(swap),
            exchangeProxy: address(swap),
            swapCallData: "mocked swap data"
        });

        uint256 flashAmount = TestStateLib.silo1().maxRepay(user);

        uint256 amountIn = flashAmount * 111 / 100;
        swap.setSwap(TestStateLib.token0(), amountIn, TestStateLib.token1(), amountIn * 99 / 100);

        LeverageUsingSiloFlashloanWithGeneralSwap siloLeverage = _getLeverage();


        address silo0 = address(TestStateLib.silo0());

        vm.prank(user);
        IERC20(silo0).approve(address(siloLeverage), type(uint256).max);

        TestStateLib.enableLeverageReentrancy();

        vm.prank(user);
        siloLeverage.closeLeveragePosition(abi.encode(swapArgs), closeArgs);

        TestStateLib.disableLeverageReentrancy();
    }
}
