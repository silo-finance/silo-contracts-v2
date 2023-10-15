// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {Gas} from "./Gas.sol";

/*
forge test -vv --ffi --mt test_gas_ | grep -i '\[GAS\]'
*/
contract Deposit1stGasTest is Gas, Test {
    constructor() Gas(vm) {}

    function setUp() public {
        _gasTestsInit();
    }

    function test_gas_firstDeposit() public {
        _action(
            BORROWER,
            address(silo0),
            abi.encodeCall(ISilo.deposit, (ASSETS, BORROWER, ISilo.AssetType.Collateral)),
            "first deposit ever",
            184951
        );
    }
}
