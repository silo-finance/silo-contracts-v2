// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {MintableToken} from "../_common/MintableToken.sol";
import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc MaxTest
*/
contract MaxTest is SiloLittleHelper, Test {
    uint256 constant DEPOSIT_BEFORE = 1e18 + 9876543211;

    ISiloConfig siloConfig;
    address immutable depositor;
    address immutable borrower;

    constructor() {
        depositor = makeAddr("Depositor");
        borrower = makeAddr("Borrower");
    }

    function setUp() public {
        siloConfig = _setUpLocalFixture(SiloConfigsNames.LOCAL_NO_ORACLE_NO_LTV_SILO);
    }

    /*
    forge test -vv --ffi --mt test_maxDeposit_emptySilo
    */
    function test_maxDeposit_emptySilo() public {
        uint256 maxDeposit = silo0.maxDeposit(depositor);
        assertEq(maxDeposit, type(uint256).max, "on empty silo, MAX is just no limit");
        _deposit(maxDeposit, depositor);

        _assertWeCanNotDepositMore(silo0, depositor);
    }

    /*
    forge test -vv --ffi --mt test_maxDeposit_whenBorrow
    */
    function test_maxDeposit_whenBorrow() public {
        uint256 _initialDeposit = 1e18;

        _depositForBorrow(_initialDeposit / 3, depositor);
        _deposit(_initialDeposit / 3 * 2, borrower);
        _borrow(_initialDeposit / 3, borrower);

        assertEq(silo0.maxDeposit(borrower), type(uint256).max - (_initialDeposit / 3 * 2), "no debt - max deposit");
        assertEq(silo1.maxDeposit(borrower), 0, "can not deposit with debt");
    }

    /*
    forge test -vv --ffi --mt test_maxDeposit_withDeposit_fuzz
    */
    /// forge-config: core.fuzz.runs = 10000
    function test_maxDeposit_withDeposit_fuzz(uint256 _initialDeposit) public {
        vm.assume(_initialDeposit > 0);
        vm.assume(_initialDeposit < type(uint256).max); // max case is covered on test_maxDeposit_emptySilo

        _deposit(_initialDeposit, depositor);

        uint256 maxDeposit = silo0.maxDeposit(depositor);
        assertEq(maxDeposit, type(uint256).max - _initialDeposit, "with deposit, max is MAX - deposit");

        _deposit(maxDeposit, depositor);

        _assertWeCanNotDepositMore(silo0, depositor);
    }

    /*
    forge test -vv --ffi --mt test_maxDeposit_withInterest_fuzz
    */
    /// forge-config: core.fuzz.runs = 10000
    function test_maxDeposit_withInterest_fuzz(uint128 _initialDeposit) public {
        vm.assume(_initialDeposit > 3); // we need to be able /3

        _depositForBorrow(_initialDeposit / 3, depositor);

        _deposit(_initialDeposit / 3 * 2, borrower);
        _borrow(_initialDeposit / 3, borrower);

        vm.warp(block.timestamp + 100 days);

        uint256 maxDeposit = silo1.maxDeposit(depositor);

        assertLt(
            maxDeposit,
            type(uint256).max - (_initialDeposit / 3 * 2),
            "with interest we expecting less than simply sub the initial deposit"
        );

        _depositForBorrow(maxDeposit, depositor);

        _assertWeCanNotDepositMore(silo1, depositor);
    }
}
