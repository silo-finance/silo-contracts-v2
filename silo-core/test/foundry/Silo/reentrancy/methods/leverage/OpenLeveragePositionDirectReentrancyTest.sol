// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {
    LeverageUsingSiloFlashloanWithGeneralSwap
} from "silo-core/contracts/leverage/LeverageUsingSiloFlashloanWithGeneralSwap.sol";
import {ILeverageUsingSiloFlashloan} from "silo-core/contracts/interfaces/ILeverageUsingSiloFlashloan.sol";
import {ILeverageRouter} from "silo-core/contracts/interfaces/ILeverageRouter.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {MethodReentrancyTest} from "../MethodReentrancyTest.sol";
import {TestStateLib} from "../../TestState.sol";
import {RevenueModule} from "silo-core/contracts/leverage/modules/RevenueModule.sol";

contract OpenLeveragePositionDirectReentrancyTest is MethodReentrancyTest {
    function callMethod() external {
        emit log_string("\tEnsure it will revert with OnlyRouter");
        _ensureItWillRevertWithOnlyRouter();
    }

    function verifyReentrancy() external {
        _ensureItWillRevertWithOnlyRouter();
    }

    function methodDescription() external pure returns (string memory description) {
        description = "openLeveragePosition(address,(address,uint256),bytes,(address,uint256,uint8))";
    }

    function _ensureItWillRevertWithOnlyRouter() internal {
        LeverageUsingSiloFlashloanWithGeneralSwap leverage = _getLeverage();
        
        // Prepare test data
        ILeverageUsingSiloFlashloan.FlashArgs memory flashArgs = ILeverageUsingSiloFlashloan.FlashArgs({
            flashloanTarget: address(TestStateLib.silo0()),
            amount: 100e18
        });
        
        bytes memory swapArgs = "";
        
        ILeverageUsingSiloFlashloan.DepositArgs memory depositArgs = ILeverageUsingSiloFlashloan.DepositArgs({
            silo: TestStateLib.silo1(),
            amount: 100e18,
            collateralType: ISilo.CollateralType.Collateral
        });
        
        // This should revert with OnlyRouter error
        vm.expectRevert(RevenueModule.OnlyRouter.selector);
        leverage.openLeveragePosition{value: 0}(
            address(this),
            flashArgs,
            swapArgs,
            depositArgs
        );
    }

    function _getLeverage() internal returns (LeverageUsingSiloFlashloanWithGeneralSwap) {
        ILeverageRouter leverageRouter = ILeverageRouter(TestStateLib.leverageRouter());
        return LeverageUsingSiloFlashloanWithGeneralSwap(leverageRouter.LEVERAGE_IMPLEMENTATION());
    }
}
