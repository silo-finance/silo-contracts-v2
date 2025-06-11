// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ILeverageUsingSiloFlashloan} from "silo-core/contracts/interfaces/ILeverageUsingSiloFlashloan.sol";
import {IGeneralSwapModule} from "silo-core/contracts/interfaces/IGeneralSwapModule.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

// Libraries
import "forge-std/console.sol";

// Test Contracts
import {BaseHandlerLeverage} from "../../base/BaseHandlerLeverage.t.sol";

/// @title LeverageHandler
/// @notice Handler test contract for a set of actions
contract LeverageHandler is BaseHandlerLeverage {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTIONS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Random number struct to help with stack too deep errors
    struct RandomGenerator2 {
        uint8 i;
        uint8 j;
        uint8 k;
    }

    function openLeveragePosition(
        uint256 _depositAmount,
        uint256 _multiplier,
        RandomGenerator2 calldata _random
    ) external payable setup {
        _multiplier = _multiplier % 2e18; // leverage up to 2x
        uint256 _PRECISION = 1e18;

        address borrower = _getRandomActor(_random.i);
        _setTargetActor(borrower);

        address silo = _getRandomSilo(_random.j);

        ILeverageUsingSiloFlashloan.FlashArgs memory flashArgs;
        ILeverageUsingSiloFlashloan.DepositArgs memory depositArgs;
        IGeneralSwapModule.SwapArgs memory swapArgs;

        flashArgs = ILeverageUsingSiloFlashloan.FlashArgs({
            amount: _depositAmount * _multiplier / _PRECISION,
            flashloanTarget: _getOtherSilo(silo)
        });

        depositArgs = ILeverageUsingSiloFlashloan.DepositArgs({
            amount: _depositAmount,
            collateralType: ISilo.CollateralType(_random.k % 2),
            silo: ISilo(silo)
        });

        swapArgs = IGeneralSwapModule.SwapArgs({
            buyToken: depositArgs.silo.asset(),
            sellToken: ISilo(flashArgs.flashloanTarget).asset(),
            allowanceTarget: address(swapRouterMock),
            exchangeProxy: address(swapRouterMock),
            swapCallData: "mocked swap data"
        });

        // swap with 0.5% slippage
        swapRouterMock.setSwap(swapArgs.sellToken, flashArgs.amount, swapArgs.buyToken, flashArgs.amount * 995 / 1000);

        _before();

        (bool success, bytes memory returnData) = actor.proxy{value: msg.value}(
            address(siloLeverage),
            abi.encodeWithSelector(
                ILeverageUsingSiloFlashloan.openLeveragePosition.selector,
                flashArgs,
                abi.encode(swapArgs),
                depositArgs
            )
        );

        if (success) {
            _after();
            assertGt(ISilo(closeArgs.flashloanTarget).maxRepay(borrower), 0, "borrower should have debt");
        }

        assert_SiloLeverage_neverKeepsTokens();
    }

    function closeLeveragePosition(RandomGenerator2 calldata _random) external setup {
        address borrower = _getRandomActor(_random.i);
        _setTargetActor(borrower);

        address silo = _getRandomSilo(_random.j);

        ILeverageUsingSiloFlashloan.CloseLeverageArgs memory closeArgs;
        IGeneralSwapModule.SwapArgs memory swapArgs;

        closeArgs = ILeverageUsingSiloFlashloan.CloseLeverageArgs({
            flashloanTarget: _getOtherSilo(silo),
            siloWithCollateral: ISilo(silo),
            collateralType: ISilo.CollateralType(_random.k % 2)
        });

        uint256 flashAmount = ISilo(closeArgs.flashloanTarget).maxRepay(borrower);
        uint256 amountIn = flashAmount * 111 / 100;
        // swap with 0.5% slippage
        swapRouterMock.setSwap(swapArgs.sellToken, amountIn, swapArgs.buyToken, amountIn * 995 / 1000);

        swapArgs = IGeneralSwapModule.SwapArgs({
            buyToken: ISilo(closeArgs.flashloanTarget).asset(),
            sellToken: ISilo(closeArgs.siloWithCollateral).asset(),
            allowanceTarget: address(swapRouterMock),
            exchangeProxy: address(swapRouterMock),
            swapCallData: "mocked swap data"
        });

        _before();

        (bool success, bytes memory returnData) = actor.proxy(
            address(siloLeverage),
            abi.encodeWithSelector(
                ILeverageUsingSiloFlashloan.closeLeveragePosition.selector,
                abi.encode(swapArgs),
                closeArgs
            )
        );

        if (success) {
            _after();
            assertEq(ISilo(closeArgs.flashloanTarget).maxRepay(borrower), 0, "borrower should have no debt");
        }

        assert_SiloLeverage_neverKeepsTokens();
    }

    function assert_SiloLeverage_neverKeepsTokens() public {
        assertEq(_asset0.balanceOf(address(siloLeverage)), 0, "SiloLeverage should have 0 asset0");
        assertEq(_asset1.balanceOf(address(siloLeverage)), 0, "SiloLeverage should have 0 asset1");
        assertEq(address(siloLeverage).balance, 0, "SiloLeverage should have 0 ETH");
    }

    function echidna_SiloLeverage_neverKeepsTokens() external returns (bool) {
        if (_asset0.balanceOf(address(siloLeverage)) != 0) return false;
        if (_asset1.balanceOf(address(siloLeverage)) != 0) return false;

        return true;
    }
}
