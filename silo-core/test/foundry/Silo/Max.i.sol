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
        uint256 maxDeposit = silo1.maxDeposit(depositor);
        assertEq(maxDeposit, type(uint256).max, "on empty silo, MAX is just no limit");
        _depositForBorrow(maxDeposit, depositor);

        _assertWeCanNotDepositMore(depositor);
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

        _depositForBorrow(_initialDeposit, depositor);

        uint256 maxDeposit = silo1.maxDeposit(depositor);
        assertEq(maxDeposit, type(uint256).max - _initialDeposit, "with deposit, max is MAX - deposit");

        _depositForBorrow(maxDeposit, depositor);

        _assertWeCanNotDepositMore(depositor);
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

        emit log_named_decimal_uint("maxDeposit", maxDeposit, 18);

        assertLe(
            maxDeposit,
            type(uint256).max - (_initialDeposit / 3 * 2),
            "with interest we expecting less than simply sub the initial deposit"
        );

        _depositForBorrow(maxDeposit, depositor);

        _assertWeCanNotDepositMore(depositor);
    }


    /*
    forge test -vv --ffi --mt test_maxDeposit_repayWithInterest_fuzz
    */
    /// forge-config: core.fuzz.runs = 10000
    function test_maxDeposit_repayWithInterest_fuzz(
        uint128 _initialDeposit
    ) public {
//        uint128 _initialDeposit = 4;
        uint128 toBorrow = _initialDeposit / 3;

        vm.assume(_initialDeposit > 3); // we need to be able /3

        _depositForBorrow(toBorrow, depositor);

        _deposit(_initialDeposit / 3 * 2, borrower);
        _borrow(toBorrow, borrower);

        vm.warp(block.timestamp + 10 days);

        (,, address debtShareToken) = silo1.config().getShareTokens(address(silo1));

        _repayShares(type(uint256).max, IShareToken(debtShareToken).balanceOf(borrower), borrower);
        assertGt(token1.balanceOf(address(silo1)), toBorrow, "we expect to repay with interest");
        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 0, "all debt must be repay");

        uint256 maxDeposit = silo1.maxDeposit(depositor);

        emit log_named_decimal_uint("maxDeposit", maxDeposit, 18);
        emit log_named_decimal_uint("balanceOf(silo)", token1.balanceOf(address(silo1)), 18);
        emit log_named_decimal_uint("interest (with fees)", token1.balanceOf(address(silo1)) - toBorrow, 18);
        emit log_named_decimal_uint("           diff", type(uint256).max - maxDeposit, 18);

        assertEq(
            maxDeposit,
            type(uint256).max - token1.balanceOf(address(silo1)),
            "with interest we expecting less than simply sub the initial deposit"
        );

        vm.startPrank(borrower);
        token1.transfer(depositor, token1.balanceOf(borrower));

        _depositForBorrow(maxDeposit, depositor);

        emit log_named_decimal_uint("balanceOf(silo)", token1.balanceOf(address(silo1)), 18);
        emit log_named_decimal_uint("silo.getCollateralAssets", silo1.getCollateralAssets(), 18);

        _assertWeCanNotDepositMore(depositor);
    }

    /*
    forge test -vv --ffi --mt test_maxMint_emptySilo
    */
    function test_maxMint_emptySilo() public {
        uint256 maxMint = silo1.maxMint(depositor);
        assertEq(maxMint, type(uint256).max, "on empty silo, MAX is just no limit");
        _depositForBorrow(maxMint, depositor);

        _assertWeCanNotDepositMore(depositor);
    }


    // we check on silo1
    function _assertWeCanNotDepositMore(address _user) internal {
        uint256 one = 1;
        address anyUser = makeAddr("any random address ...");

        // after max, we can not deposit even 1 wei
        // we can not mint, because we max out, so we need to borrow
        _deposit(one * 10, anyUser);
        _borrow(one, anyUser);

        vm.prank(address(anyUser));
        token1.transfer(_user, one);

        vm.startPrank(_user);
        token1.approve(address(silo1), one);
        vm.expectRevert(); // we can not mint shares
        silo1.deposit(one, _user);
        vm.stopPrank();
    }
}
