// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc WithdrawWhenFractionsTest
*/
contract WithdrawWhenFractionsTest is SiloLittleHelper, Test {
    function setUp() public {
        _setUpLocalFixture();

        token1.setOnDemand(true);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_withdraw_when_fractions
    */
    function test_withdraw_when_fractions() public {
        address borrower = address(this);

        silo1.mint(632707868, borrower);
        _borrow(313517, borrower, true);

        vm.warp(block.timestamp + 195346);
        silo1.accrueInterest();
        vm.warp(block.timestamp + 130008);

        silo1.withdraw(silo1.maxWithdraw(borrower), borrower, borrower);
    }
}
