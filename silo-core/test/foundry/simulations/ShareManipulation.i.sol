// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc InterestOverflowTest

    this test checks scenario, when we overflow interest, in that case we should be able to repay and exit silo
*/
contract ShareManipulationTest is SiloLittleHelper, Test {
    function setUp() public {
        _setUpLocalFixture();
    }

    /*
    forge test -vv --ffi --mt test_if1to1RatioCanBreakWithoutInterest --gas-limit 40000000000
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_if1to1RatioCanBreakWithoutInterest_fuzz(uint64 _initial) public {
        vm.assume(_initial > 2);

        address depositor = makeAddr("depositor");
        address small = makeAddr("small");

        for(uint256 i; i < 1000; i++) {
            _deposit(_initial, depositor);
            _deposit(1, small);
            _withdraw(silo0.maxWithdraw(depositor) - 1, depositor);

            vm.warp(1);
            silo0.accrueInterest();

            assertEq(1, silo1.convertToAssets(1), "1:1");
        }
    }

    /*
    forge test -vv --ffi --mt test_collateral_simulation_withInterest
    */
    function test_collateral_simulation_withInterest() public {
        address borrower = makeAddr("borrower");
        address depositor = makeAddr("depositor");
        address small = makeAddr("small");

        _depositForBorrow(type(uint64).max, depositor);

        for(uint256 i; i < 100; i++) {
            uint256 collateral = 34 * (10 ** (i % 18) + 1);
            uint256 toBorrow = collateral / 5 + 1;

            _depositCollateral(collateral, borrower, TWO_ASSETS);
            _deposit(1, small);

            uint256 borrowShares = _borrow(toBorrow, borrower);

            vm.warp(block.timestamp + 1);

            _repayShares(type(uint256).max, borrowShares - 1, borrower);

            // _withdraw(silo0.maxWithdraw(depositor) - 1, depositor);

            _printCollateralRatio();
            _printBorrowRatio();
        }
    }

    /*
    forge test -vv --ffi --mt test_simulation_shares
    */
    function test_debt_simulation_shares() public {
        address borrower = makeAddr("borrower");

        _depositCollateral(100e18, borrower, TWO_ASSETS);
        _depositForBorrow(100e18, makeAddr("depositor"));

        _borrow(1, borrower);

        for(uint256 i; i < 18; i++) {
            _borrow(1 * (10 ** i), borrower);
            _printBorrowRatio();

        _repay(1 * (10 ** i), borrower);
        }

        _printBorrowRatio();
    }

    function _printBorrowRatio() internal {
        emit log_named_uint("1 share =", silo1.previewBorrowShares(1));
    }

    function _printCollateralRatio() internal {
        emit log_named_uint("1 collateral share =", silo1.convertToAssets(1));
    }
}
