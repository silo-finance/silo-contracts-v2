// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {Gas} from "./Gas.sol";

/*
forge test -vv --ffi --mt test_gas_ | grep -i '\[GAS\]'
*/
contract RepayPartAccrueInterestGasTest is Gas, Test {
    constructor() Gas(vm) {}

    function setUp() public {
        _gasTestsInit();

        vm.prank(DEPOSITOR);
        silo1.deposit(ASSETS * 5, DEPOSITOR);

        vm.startPrank(BORROWER);
        silo0.deposit(ASSETS * 10, BORROWER);
        silo1.borrow(ASSETS, BORROWER, BORROWER);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);
    }

    function test_gas_repayPartWithInterest() public {
        _action(
            BORROWER,
            address(silo1),
            abi.encodeCall(ISilo.repay, (ASSETS / 2, BORROWER)),
            "partial repay with accrue interest",
            166414
        );
    }
}
