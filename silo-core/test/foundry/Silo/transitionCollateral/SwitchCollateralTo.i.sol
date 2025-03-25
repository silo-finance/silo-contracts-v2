// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc SwitchCollateralToTest
*/
contract SwitchCollateralToTest is SiloLittleHelper, Test {
    ISiloConfig siloConfig;

    function setUp() public {
        siloConfig = _setUpLocalFixture();
    }

    /*
    forge test -vv --ffi --mt test_switchCollateralToThisSilo_pass
    */
    function test_switchCollateralToThisSilo_pass() public {
        uint256 assets = 1e18;
        address depositor = makeAddr("Depositor");
        address borrower = makeAddr("Borrower");

        _deposit(assets, borrower);
        _depositForBorrow(assets, borrower);
        _depositForBorrow(assets, depositor);

        vm.expectEmit(address(silo1));
        emit ISilo.CollateralTypeChanged(borrower);

        _borrow(assets / 2, borrower);

        ISiloConfig.ConfigData memory collateral;
        ISiloConfig.ConfigData memory debt;

        (collateral, debt) = siloConfig.getConfigsForSolvency(borrower);

        vm.prank(borrower);
        silo1.switchCollateralToThisSilo();
        (collateral, debt) = siloConfig.getConfigsForSolvency(borrower);

        ISilo siloWithDeposit = silo0;
        vm.prank(borrower);
        siloWithDeposit.withdraw(assets, borrower, borrower);

        assertGt(siloLens.getLtv(silo0, borrower), 0, "user has debt");
        assertTrue(silo0.isSolvent(borrower), "user is solvent");
    }

    /*
    forge test -vv --ffi --mt test_switchCollateralToThisSilo_NotSolvent
    */
    function test_switchCollateralToThisSilo_NotSolvent() public {
        uint256 assets = 1e18;
        address depositor = makeAddr("Depositor");
        address borrower = makeAddr("Borrower");

        _deposit(assets, borrower);
        _deposit(1, borrower);
        _depositForBorrow(assets, depositor);
        _borrow(assets / 2, borrower);

        vm.prank(borrower);
        vm.expectRevert(ISilo.NotSolvent.selector);
        silo1.switchCollateralToThisSilo();
    }

    /*
    forge test -vv --ffi --mt test_switchCollateralToThisSilo_AlreadySet
    */
    function test_switchCollateralToThisSilo_AlreadySet() public {
        uint256 assets = 1e18;
        address depositor = makeAddr("Depositor");
        address borrower = makeAddr("Borrower");

        _deposit(assets, borrower);
        _deposit(1, borrower);
        _depositForBorrow(assets, depositor);
        _borrow(assets / 2, borrower);

        vm.prank(borrower);
        vm.expectRevert(ISilo.CollateralSiloAlreadySet.selector);
        silo0.switchCollateralToThisSilo();
    }
}
