// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloLiquidation} from "silo-core/contracts/interfaces/ISiloLiquidation.sol";

import {Gas} from "./Gas.sol";

/*
forge test -vv --ffi --mt test_gas_ | grep -i '\[GAS\]'
*/
contract LiquidationAccrueInterestGasTest is Gas, Test {
    constructor() Gas(vm) {}

    function setUp() public {
        _gasTestsInit();

        vm.prank(DEPOSITOR);
        silo1.deposit(ASSETS, DEPOSITOR);

        vm.startPrank(BORROWER);
        silo0.deposit(ASSETS * 5, BORROWER);
        silo1.borrow(ASSETS, BORROWER, BORROWER);
        vm.stopPrank();

        vm.warp(block.timestamp + 13 days);
    }

    /*
    forge test -vvv --ffi --mt test_gas_liquidationCallWithInterest
    */
    function test_gas_liquidationCallWithInterest() public {
        _action(
            DEPOSITOR,
            address(silo1),
            abi.encodeCall(ISiloLiquidation.liquidationCall, (address(token0), address(token1), BORROWER, ASSETS / 2, false)),
            "liquidationCall with accrue interest",
            322514
        );
    }
}
