// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IERC20R} from "silo-core/contracts/interfaces/IERC20R.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc SwitchCollateralToTest
*/
contract SwitchCollateralToTest is SiloLittleHelper, Test {
    ISiloConfig siloConfig;

    function setUp() public {
        siloConfig = _setUpLocalFixture();
    }

    /*
    forge test -vv --ffi --mt test_switchCollateralTo_pass_
    */
    function test_switchCollateralTo_pass_1token() public {
        _switchCollateralTo_pass();
    }

    function _switchCollateralTo_pass() private {
        uint256 assets = 1e18;
        address depositor = makeAddr("Depositor");
        address borrower = makeAddr("Borrower");

        _deposit(assets, borrower);
        _depositForBorrow(assets, borrower);
        _depositForBorrow(assets, depositor);

        _borrow(assets / 2, borrower);

        ISiloConfig.ConfigData memory collateral;
        ISiloConfig.ConfigData memory debt;

        (collateral, debt) = siloConfig.getConfigs(borrower);

        vm.prank(borrower);
        silo0.switchCollateralTo();
        (collateral, debt) = siloConfig.getConfigs(borrower);

        ISilo siloWithDeposit = silo0;
        vm.prank(borrower);
        siloWithDeposit.withdraw(assets, borrower, borrower);

        assertGt(siloLens.getLtv(silo0, borrower), 0, "user has debt");
        assertTrue(silo0.isSolvent(borrower), "user is solvent");
    }

    /*
    forge test -vv --mt test_switchCollateralTo_NotSolvent_
    */
    function test_switchCollateralTo_NotSolvent_1token() public {
        _switchCollateralTo_NotSolvent();
    }

    function _switchCollateralTo_NotSolvent() private {
        uint256 assets = 1e18;
        address depositor = makeAddr("Depositor");
        address borrower = makeAddr("Borrower");

        _deposit(assets, borrower);
        _deposit(1, borrower);
        _depositForBorrow(assets, depositor);
        _borrow(assets / 2, borrower);

        vm.prank(borrower);
        vm.expectRevert(ISilo.NotSolvent.selector);
        silo1.switchCollateralTo();
    }

    function test_switchCollateralTo_NoDebt() public {
        _switchCollateralTo_NoDebt();
    }

    function _switchCollateralTo_NoDebt() private {
        address borrower = makeAddr("Borrower");

        vm.prank(borrower);
        vm.expectRevert(ISiloConfig.NoDebt.selector);
        silo0.switchCollateralTo();
    }
}
