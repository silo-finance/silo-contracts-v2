// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20Permit} from "openzeppelin5/token/ERC20/extensions/IERC20Permit.sol";

import {
    LeverageUsingSiloFlashloanWithGeneralSwap
    } from "silo-core/contracts/leverage/LeverageUsingSiloFlashloanWithGeneralSwap.sol";
import {ILeverageUsingSiloFlashloan} from "silo-core/contracts/interfaces/ILeverageUsingSiloFlashloan.sol";
import {IGeneralSwapModule} from "silo-core/contracts/interfaces/IGeneralSwapModule.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ICrossReentrancyGuard} from "silo-core/contracts/interfaces/ICrossReentrancyGuard.sol";
import {TransientReentrancy} from "silo-core/contracts/hooks/_common/TransientReentrancy.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";
import {CloseLeveragePositionReentrancyTest} from "./CloseLeveragePositionReentrancyTest.sol";

contract CloseLeveragePositionPermitReentrancyTest is CloseLeveragePositionReentrancyTest {
    function callMethod() external override {
        _openLeverage();

        (
            ILeverageUsingSiloFlashloan.CloseLeverageArgs memory closeArgs,
            IGeneralSwapModule.SwapArgs memory swapArgs
        ) = _closeLeverageArgs();

        uint256 flashAmount = TestStateLib.silo1().maxRepay(wallet.addr);

        uint256 amountIn = flashAmount * 111 / 100;
        swap.setSwap(TestStateLib.token0(), amountIn, TestStateLib.token1(), amountIn * 99 / 100);

        LeverageUsingSiloFlashloanWithGeneralSwap siloLeverage = _getLeverage();

        TestStateLib.enableLeverageReentrancy();

        ILeverageUsingSiloFlashloan.Permit memory permit = _generatePermit(address(TestStateLib.silo0()));

        vm.prank(wallet.addr);
        siloLeverage.closeLeveragePositionPermit(abi.encode(swapArgs), closeArgs, permit);

        TestStateLib.disableLeverageReentrancy();
    }

    function verifyReentrancy() external override {
        LeverageUsingSiloFlashloanWithGeneralSwap siloLeverage = _getLeverage();

        (
            ILeverageUsingSiloFlashloan.CloseLeverageArgs memory closeArgs,
            IGeneralSwapModule.SwapArgs memory swapArgs
        ) = _closeLeverageArgs();

        ILeverageUsingSiloFlashloan.Permit memory permit = _generatePermit(address(TestStateLib.silo0()));

        vm.expectRevert(TransientReentrancy.ReentrancyGuardReentrantCall.selector);
        siloLeverage.closeLeveragePositionPermit(abi.encode(swapArgs), closeArgs, permit);
    }

    function methodDescription() external pure override returns (string memory description) {
        // solhint-disable-next-line max-line-length
        description = "closeLeveragePositionPermit(bytes,(address,address,uint8),(uint256,uint256,uint8,bytes32,bytes32))";
    }
}
