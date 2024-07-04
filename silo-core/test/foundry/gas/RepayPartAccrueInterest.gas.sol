// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {Gas} from "./Gas.sol";

/*
forge test -vv --ffi --mt test_gas_ | grep -i '\[GAS\]'
*/
contract RepayPartAccrueInterestGasTest is Gas, Test {
    function setUp() public {
        _gasTestsInit();

        vm.prank(DEPOSITOR);
        silo1.deposit(ASSETS * 5, DEPOSITOR);

        vm.startPrank(BORROWER);
        silo0.deposit(ASSETS * 10, BORROWER);
        silo1.borrow(ASSETS, BORROWER, BORROWER, false /* sameAsset */);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);
    }

    // forge test -vv --ffi --mt test_gas_repayPartWithInterest
    function test_gas_repayPartWithInterest() public {
        _action(
            BORROWER,
            address(silo1),
            abi.encodeWithSignature("repay(uint256,address)", ASSETS / 2, BORROWER),
            "RepayPartAccrueInterest partial with accrue interest",
            133434
        );
    }
}
