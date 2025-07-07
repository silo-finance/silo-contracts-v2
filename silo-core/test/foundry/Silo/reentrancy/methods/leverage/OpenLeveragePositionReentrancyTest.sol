// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {
    LeverageUsingSiloFlashloanWithGeneralSwap
} from "silo-core/contracts/leverage/LeverageUsingSiloFlashloanWithGeneralSwap.sol";
import {ILeverageUsingSiloFlashloan} from "silo-core/contracts/interfaces/ILeverageUsingSiloFlashloan.sol";
import {IGeneralSwapModule} from "silo-core/contracts/interfaces/IGeneralSwapModule.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IERC20R} from "silo-core/contracts/interfaces/IERC20R.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ICrossReentrancyGuard} from "silo-core/contracts/interfaces/ICrossReentrancyGuard.sol";
import {SwapRouterMock} from "silo-core/test/foundry/leverage/mocks/SwapRouterMock.sol";
import {WETH} from "silo-core/test/foundry/leverage/mocks/WETH.sol";
import {TransientReentrancy} from "silo-core/contracts/hooks/_common/TransientReentrancy.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";
import {MaliciousToken} from "../../MaliciousToken.sol";

contract OpenLeveragePositionReentrancyTest is MethodReentrancyTest {
    SwapRouterMock public swap = new SwapRouterMock();

    function callMethod() external virtual{
        _openLeverage();
    }

    function verifyReentrancy() external virtual {
        address user = makeAddr("User");
        // Prepare leverage arguments
        ILeverageUsingSiloFlashloan.FlashArgs memory flashArgs = ILeverageUsingSiloFlashloan.FlashArgs({
            flashloanTarget: address(0),
            amount: 0
        });

        ILeverageUsingSiloFlashloan.DepositArgs memory depositArgs = ILeverageUsingSiloFlashloan.DepositArgs({
            silo: TestStateLib.silo0(),
            amount: 0,
            collateralType: ISilo.CollateralType.Collateral
        });

        // Mock swap module arguments
        IGeneralSwapModule.SwapArgs memory swapArgs = IGeneralSwapModule.SwapArgs({
            buyToken: address(0),
            sellToken: address(0),
            allowanceTarget: address(0),
            exchangeProxy: address(0),
            swapCallData: "mocked swap data"
        });

        // Execute leverage position opening
        LeverageUsingSiloFlashloanWithGeneralSwap leverage = _getLeverage();

        vm.prank(user);
        vm.expectRevert(TransientReentrancy.ReentrancyGuardReentrantCall.selector);
        leverage.openLeveragePosition(flashArgs, abi.encode(swapArgs), depositArgs);
    }

    function methodDescription() external pure virtual returns (string memory description) {
        description = "openLeveragePosition((address,uint256),bytes,(address,uint256,uint8))";
    }

    function _getLeverage() internal view returns (LeverageUsingSiloFlashloanWithGeneralSwap) {
        return LeverageUsingSiloFlashloanWithGeneralSwap(TestStateLib.leverage());
    }

    function _openLeverage() internal {
        address user = makeAddr("User");
        uint256 depositAmount = 0.1e18;
        uint256 flashloanAmount = depositAmount * 1.08e18 / 1e18;

        _depositsAndApprovals(user, depositAmount, flashloanAmount, swap);

        // Prepare leverage arguments
        ILeverageUsingSiloFlashloan.FlashArgs memory flashArgs = ILeverageUsingSiloFlashloan.FlashArgs({
            flashloanTarget: address(TestStateLib.silo1()),
            amount: flashloanAmount
        });

        ILeverageUsingSiloFlashloan.DepositArgs memory depositArgs = ILeverageUsingSiloFlashloan.DepositArgs({
            silo: TestStateLib.silo0(),
            amount: depositAmount,
            collateralType: ISilo.CollateralType.Collateral
        });

        // Mock swap module arguments
        IGeneralSwapModule.SwapArgs memory swapArgs = IGeneralSwapModule.SwapArgs({
            buyToken: TestStateLib.token0(),
            sellToken: TestStateLib.token1(),
            allowanceTarget: address(swap),
            exchangeProxy: address(swap),
            swapCallData: "mocked swap data"
        });

        // mock the swap: debt token -> collateral token, price is 1:1, lt's mock some fee
        swap.setSwap(TestStateLib.token1(), flashloanAmount, TestStateLib.token0(), flashloanAmount * 99 / 100);

        TestStateLib.enableLeverageReentrancy();
        
        // Execute leverage position opening
        LeverageUsingSiloFlashloanWithGeneralSwap leverage = _getLeverage();


        emit log_string("[OpenLeveragePositionReentrancyTest] before openLeveragePosition");
        vm.prank(user);
        leverage.openLeveragePosition(flashArgs, abi.encode(swapArgs), depositArgs);

        TestStateLib.disableLeverageReentrancy();
    }

    function _depositsAndApprovals(
        address _user,
        uint256 _depositAmount,
        uint256 _flashloanAmount,
        SwapRouterMock _swap
    ) internal {
        LeverageUsingSiloFlashloanWithGeneralSwap leverage = _getLeverage();

        address liquidityProvider = makeAddr("LiquidityProvider");
        uint256 liquidityAmount = 100e18;

        address token0 = TestStateLib.token0();
        address token1 = TestStateLib.token1();

        ISilo silo0 = TestStateLib.silo0();
        ISilo silo1 = TestStateLib.silo1();
        
        // Mint tokens for user. Silo reentrancy test is disabled.
        TestStateLib.disableReentrancy();

        MaliciousToken(token0).mint(_user, _depositAmount);
        MaliciousToken(token1).mint(liquidityProvider, liquidityAmount);

        vm.prank(liquidityProvider);
        MaliciousToken(token1).approve(address(silo1), liquidityAmount);

        vm.prank(liquidityProvider);
        silo1.deposit(liquidityAmount, liquidityProvider, ISilo.CollateralType.Collateral);
        
        // Set up approvals
        vm.startPrank(_user);
        
        // Approve leverage contract to pull deposit tokens
        MaliciousToken(TestStateLib.token0()).approve(address(leverage), _depositAmount);
        
        // Get debt share token from silo1
        ISiloConfig config = TestStateLib.silo1().config();
        (,, address debtShareToken) = config.getShareTokens(address(TestStateLib.silo1()));
        
        // Calculate and set debt receive approval
        uint256 debtReceiveApproval = leverage.calculateDebtReceiveApproval(
            TestStateLib.silo1(), 
            _flashloanAmount
        );
        IERC20R(debtShareToken).setReceiveApproval(address(leverage), debtReceiveApproval);
        
        vm.stopPrank();
    }
}
