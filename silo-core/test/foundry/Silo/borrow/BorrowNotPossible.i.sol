// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc BorrowNotPossibleTest
*/
contract BorrowNotPossibleTest is SiloLittleHelper, Test {
    function setUp() public {
        _setUpLocalFixture(SiloConfigsNames.LOCAL_NOT_BORROWABLE);

        ISiloConfig.ConfigData memory cfg0 = silo0.config().getConfig(address(silo0));
        ISiloConfig.ConfigData memory cfg1 = silo0.config().getConfig(address(silo1));

        assertEq(cfg0.maxLtv, 0, "borrow OFF");
        assertGt(cfg1.maxLtv, 0, "borrow ON");
    }

    /*
    forge test -vv --ffi --mt test_borrow_possible_for_token0
    */
    function test_borrow_possible_for_token0() public {
        uint256 depositAssets = 1e18;
        address borrower = makeAddr("Borrower");
        address depositor = makeAddr("Depositor");

        _deposit(depositAssets, depositor, ISilo.CollateralType.Collateral);
        _depositForBorrow(depositAssets, borrower);

        vm.prank(borrower);
        silo0.borrow(1, borrower, borrower);
    }

    /*
    forge test -vv --ffi --mt test_borrow_not_possible_for_token1
    */
    function test_borrow_not_possible_for_token1() public {
        uint256 depositAssets = 1e18;
        address borrower = makeAddr("Borrower");
        address depositor = makeAddr("Depositor");

        _deposit(depositAssets, borrower, ISilo.CollateralType.Collateral);
        _depositForBorrow(depositAssets, depositor);

        vm.prank(borrower);
        vm.expectRevert(ISilo.AboveMaxLtv.selector);
        silo1.borrow(1, borrower, borrower);
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vv --ffi --mt test_borrow_without_collateral
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_borrow_without_collateral(uint256 _depositAmount, uint256 _borrowAmount) public {
        vm.assume(_borrowAmount > 0);
        vm.assume(_depositAmount > _borrowAmount);
        // to avoid `panic: arithmetic underflow or overflow` on InterestRateModelV2.sol::getCompoundInterestRate
        vm.assume(_depositAmount < type(uint256).max / 1e18);

        address depositor = makeAddr("Depositor");

        _depositForBorrow(_depositAmount, depositor);

        vm.expectRevert(ISilo.AboveMaxLtv.selector);
        _borrow(_borrowAmount, address(this));
    }
}
