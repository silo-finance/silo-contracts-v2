// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ILeverageBorrower} from "silo-core/contracts/interfaces/ILeverageBorrower.sol";
import {Silo} from "silo-core/contracts/Silo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {HookCallsOutsideActionTest} from "./hook-receivers/HookCallsOutsideAction.t.sol";

/*
FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc CrossReentracyCheckTest
*/
contract CrossReentracyCheckTest is HookCallsOutsideActionTest {
    function _tryReenter() internal override {
        _disableHooks();

        _reentrancyCheck_Deposit();
        _reentrancyCheck_Withdraw();
        _reentrancyCheck_Redeem();
        _reentrancyCheck_Mint();
        _reentrancyCheck_TransitionCollateral();
        _reentrancyCheck_SwithCollateralTo();
        _reentrancyCheck_LeverageSameAsset();
        _reentrancyCheck_Borrow();
        _reentrancyCheck_BorrowShare();
        _reentrancyCheck_Repay();
        _reentrancyCheck_repayShares();
        _reentrancyCheck_leverage();

        _enableHooks();
    }

    function _reentrancyCheck_Deposit() internal {
        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        silo0.deposit(1000, address(0));

        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        silo0.deposit(1000, address(0), ISilo.CollateralType.Protected);
    }

    function _reentrancyCheck_Withdraw() internal {
        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        silo0.withdraw(1000, address(0), address(0));

        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        silo0.withdraw(1000, address(0), address(0), ISilo.CollateralType.Protected);
    }

    function _reentrancyCheck_Redeem() internal {
        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        silo0.redeem(1000, address(0), address(0));

        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        silo0.redeem(1000, address(0), address(0), ISilo.CollateralType.Protected);
    }

    function _reentrancyCheck_Mint() internal {
        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        silo0.mint(1000, address(0), ISilo.CollateralType.Protected);
    }

    function _reentrancyCheck_SwithCollateralTo() internal {
        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        silo0.switchCollateralTo(false);
    }

    function _reentrancyCheck_LeverageSameAsset() internal {
        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        silo0.leverageSameAsset(1000, 1000, address(0), ISilo.CollateralType.Protected);
    }

    function _reentrancyCheck_Borrow() internal {
        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        silo0.borrow(1000, address(0), address(0), false);

        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        silo0.borrow(1000, address(0), address(0), true);
    }

    function _reentrancyCheck_BorrowShare() internal {
        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        silo0.borrowShares(1000, address(0), address(0), false);

        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        silo0.borrowShares(1000, address(0), address(0), true);
    }

    function _reentrancyCheck_TransitionCollateral() internal {
        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        silo0.transitionCollateral(1000, address(0), ISilo.CollateralType.Protected);
    }

    function _reentrancyCheck_Repay() internal {
        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        silo0.repay(1000, address(0));
    }

    function _reentrancyCheck_repayShares() internal {
        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        silo0.repayShares(1000, address(0));
    }

    function _reentrancyCheck_leverage() internal {
        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        silo0.leverage(1000, ILeverageBorrower(address(0)), address(0), false, "");

        vm.expectRevert(ISiloConfig.CrossReentrantCall.selector);
        silo0.leverage(1000, ILeverageBorrower(address(0)), address(0), true, "");
    }

    function _disableHooks() internal {
        _setNoHooks();
        silo0.updateHooks();
        silo1.updateHooks();
    }

    function _enableHooks() internal {
        _setAllHooks();
        silo0.updateHooks();
        silo1.updateHooks();
    }
}
