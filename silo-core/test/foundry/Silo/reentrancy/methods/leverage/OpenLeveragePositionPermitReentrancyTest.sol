// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {
    LeverageUsingSiloFlashloanWithGeneralSwap
} from "silo-core/contracts/leverage/LeverageUsingSiloFlashloanWithGeneralSwap.sol";
import {ILeverageUsingSiloFlashloan} from "silo-core/contracts/interfaces/ILeverageUsingSiloFlashloan.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ICrossReentrancyGuard} from "silo-core/contracts/interfaces/ICrossReentrancyGuard.sol";
import {ILeverageUsingSiloFlashloan} from "silo-core/contracts/interfaces/ILeverageUsingSiloFlashloan.sol";
import {IGeneralSwapModule} from "silo-core/contracts/interfaces/IGeneralSwapModule.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";
import {MaliciousToken} from "../../MaliciousToken.sol";
import {OpenLeveragePositionReentrancyTest} from "./OpenLeveragePositionReentrancyTest.sol";

contract OpenLeveragePositionPermitReentrancyTest is OpenLeveragePositionReentrancyTest {
    function callMethod() external override {
        address user = wallet.addr;
        uint256 depositAmount = 0.1e18;
        uint256 flashloanAmount = depositAmount * 1.08e18 / 1e18;

        _depositLiquidity();
        _mintUserTokensAndApprove(user, depositAmount, flashloanAmount, swap, true);

        // Prepare leverage arguments
        (
            ILeverageUsingSiloFlashloan.FlashArgs memory flashArgs,
            ILeverageUsingSiloFlashloan.DepositArgs memory depositArgs,
            IGeneralSwapModule.SwapArgs memory swapArgs
        ) = _prepareLeverageArgs(flashloanAmount, depositAmount);

        // mock the swap: debt token -> collateral token, price is 1:1, lt's mock some fee
        swap.setSwap(TestStateLib.token1(), flashloanAmount, TestStateLib.token0(), flashloanAmount * 99 / 100);

        TestStateLib.enableLeverageReentrancy();
        
        // Execute leverage position opening
        LeverageUsingSiloFlashloanWithGeneralSwap leverage = _getLeverage();

        vm.startPrank(user);

        leverage.openLeveragePositionPermit({
            _flashArgs: flashArgs,
            _swapArgs: abi.encode(swapArgs),
            _depositArgs: depositArgs,
            _depositAllowance: _generatePermit(TestStateLib.token0())
        });

        vm.stopPrank();

        TestStateLib.disableLeverageReentrancy();
    }

    function verifyReentrancy() external override{
    }

    function methodDescription() external pure override returns (string memory description) {
        description = // solhint-disable-next-line max-line-length
            "openLeveragePositionPermit((address,uint256),bytes,(address,uint256,uint8),(uint256,uint256,uint8,bytes32,bytes32))";
    }
}
