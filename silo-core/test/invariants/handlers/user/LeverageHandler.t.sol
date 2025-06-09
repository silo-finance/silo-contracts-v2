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
import {Actor} from "../../utils/Actor.sol";
import {BaseHandler} from "../../base/BaseHandler.t.sol";

/// @title LeverageHandler
/// @notice Handler test contract for a set of actions
contract LeverageHandler is BaseHandler {
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
        RandomGenerator2 memory _random
    ) external payable {
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

        // this data should be provided by BE API
        // NOTICE: user needs to give allowance for swap router to use tokens
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
        siloLeverage.openLeveragePosition(flashArgs, abi.encode(swapArgs), depositArgs);
        _after();
    }

//        _before();
//        (success, returnData) = actor.proxy(
//            address(liquidationModule),
//            abi.encodeWithSelector(
//                ILeverageUsingSiloFlashloan.liquidationCall.selector,
//                collateralAsset,
//                debtAsset,
//                borrower,
//                _debtToCover,
//                _receiveSToken
//            )
//        );
//
//        if (success) {
//            _after();
//        }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         OWNER ACTIONS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
