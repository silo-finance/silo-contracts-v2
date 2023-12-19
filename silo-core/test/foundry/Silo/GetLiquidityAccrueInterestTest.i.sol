// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {MintableToken} from "../_common/MintableToken.sol";
import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc DepositTest
*/
contract GetLiquidityAccrueInterestTest is SiloLittleHelper, Test {
    ISiloConfig siloConfig;

    address immutable depositor;
    address immutable borrower;

    constructor() {
        depositor = makeAddr("Depositor");
        borrower = makeAddr("Borrower");
    }

    function setUp() public {
        siloConfig = _setUpLocalFixture();
    }

    /*
    forge test -vv --ffi --mt test_liquidity_zero
    */
    function test_liquidity_zero() public {
        assertEq(silo0.getLiquidity(), 0, "no liquidity after deploy 0");
        assertEq(silo0.getLiquidityAccrueInterest(), 0, "no liquidity after deploy 0");
        assertEq(silo1.getLiquidity(), 0, "no liquidity after deploy 1");
        assertEq(silo1.getLiquidityAccrueInterest(), 0, "no liquidity after deploy 1");
    }

    /*
    forge test -vv --ffi --mt test_liquidity_whenDeposit
    */
    function test_liquidity_whenDeposit(uint128 _assets) public {
        vm.assume(_assets > 0);

        _deposit(_assets, depositor, ISilo.AssetType.Protected);
        _deposit(_assets, depositor);

        assertEq(silo0.getLiquidity(), _assets, "[0] expect liquidity");
        assertEq(silo0.getLiquidityAccrueInterest(), _assets, "[0] expect liquidity, no interest");

        assertEq(silo1.getLiquidity(), 0, "[1] no liquidity after deploy 1");
        assertEq(silo1.getLiquidityAccrueInterest(), 0, "[1] no liquidity after deploy 1");
    }

    /*
    forge test -vv --ffi --mt test_liquidity_whenProtected
    */
    function test_liquidity_whenProtected(uint256 _assets) public {
        vm.assume(_assets > 0);

        _deposit(_assets, depositor, ISilo.AssetType.Protected);

        assertEq(silo0.getLiquidity(), 0, "[0] expect liquidity");
        assertEq(silo0.getLiquidityAccrueInterest(), 0, "[0] expect liquidity, no interest");

        assertEq(silo1.getLiquidity(), 0, "[1] no liquidity after deploy 1");
        assertEq(silo1.getLiquidityAccrueInterest(), 0, "[1] no liquidity after deploy 1");
    }

    /*
    forge test -vv --ffi --mt test_liquidity_whenDepositAndBorrow
    */
    function test_liquidity_whenDepositAndBorrow(uint128 _toDeposit, uint128 _toBorrow) public {
        vm.assume(_toDeposit > 0);
        vm.assume(_toBorrow > 0);
        vm.assume(_toBorrow < _toDeposit / 2);

        _makeDeposit(silo1, token1, _toDeposit, depositor, ISilo.AssetType.Protected);
        _depositForBorrow(_toDeposit, depositor);

        _deposit(_toDeposit, borrower);
        _borrow(_toBorrow, borrower);

        assertEq(silo0.getLiquidity(), _toDeposit, "[0] expect collateral");
        assertEq(silo0.getLiquidityAccrueInterest(), _toDeposit, "[0] expect collateral, no interest");

        assertEq(silo1.getLiquidity(), _toDeposit - _toBorrow, "[1] expect diff after borrow");
        assertEq(silo1.getLiquidityAccrueInterest(), _toDeposit - _toBorrow, "[1] expect diff after borrow (interest)");
    }

    /*
    forge test -vv --ffi --mt test_liquidity_whenDepositAndBorrowWithInterest
    */
    function test_liquidity_whenDepositAndBorrowWithInterest(uint128 _toDeposit, uint128 _toBorrow) public {
        vm.assume(_toDeposit > 0);
        vm.assume(_toBorrow > 0);
        vm.assume(_toBorrow < _toDeposit / 2);

        _makeDeposit(silo1, token1, _toDeposit, depositor, ISilo.AssetType.Protected);
        _depositForBorrow(_toDeposit, depositor);

        _deposit(_toDeposit, borrower, ISilo.AssetType.Protected);
        _deposit(_toDeposit, borrower);
        _borrow(_toBorrow, borrower);

        vm.warp(block.timestamp + 100 days);

        uint256 silo0_getLiquidity = silo0.getLiquidity();
        uint256 silo1_getLiquidity = silo1.getLiquidity();
        uint256 silo0_getLiquidityAccrueInterest = silo0.getLiquidityAccrueInterest();
        uint256 silo1_getLiquidityAccrueInterest = silo1.getLiquidityAccrueInterest();

        uint256 accruedInterest0 = silo0.accrueInterest();
        assertEq(accruedInterest0, 0, "[0] expect no interest on silo0");

        uint256 accruedInterest1 = silo1.accrueInterest();

        assertEq(silo0_getLiquidity, _toDeposit, "[0] expect same liquidity, because no borrow on this silo");
        assertEq(silo0_getLiquidityAccrueInterest, _toDeposit, "[0] same liquidity, no interest");

        assertEq(silo1_getLiquidity, _toDeposit - _toBorrow, "[1] expect liquidity without counting in interests");
        assertLe(silo1_getLiquidity, silo0.getLiquidity(), "[1] new liquidity() must not be smaller after interest");

        assertEq(
            silo1_getLiquidityAccrueInterest,
            silo1.getLiquidityAccrueInterest(), "[1] expect getLiquidityAccrueInterest() calculations correct"
        );

        assertEq(
            silo1_getLiquidityAccrueInterest,
            silo1.getLiquidity(), "[1] expect getLiquidityAccrueInterest() == getLiquidity() when no interest involved"
        );

        assertLe(
            silo1.getLiquidity(),
            silo1_getLiquidity + accruedInterest1,
            "[1] current liquidity can not be higher that previous + accruedInterest1 because of fees"
        );
    }
}
