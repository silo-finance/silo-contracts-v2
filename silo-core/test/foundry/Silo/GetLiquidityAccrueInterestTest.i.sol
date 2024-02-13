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
        assertEq(silo0.getLiquidity(), 0, "no liquidity 0");
        assertEq(silo1.getLiquidity(), 0, "no liquidity after deploy 1");
        assertEq(silo1.getLiquidity(), 0, "no collateral liquidity 1");

        assertEq(silo1.getProtectedAssets(), 0, "no protected liquidity 1");
    }

    /*
    forge test -vv --ffi --mt test_liquidity_whenDeposit
    */
    function test_liquidity_whenDeposit(uint128 _assets) public {
        vm.assume(_assets > 0);

        if (_assets > 1) _deposit(_assets / 2, depositor, ISilo.AssetType.Protected);
        _deposit(_assets, depositor);

        assertEq(silo0.getLiquidity(), _assets, "[0] expect liquidity");
        assertEq(silo0.getLiquidity(), _assets, "[0] expect collateral liquidity, no interest");
        assertEq(silo0.getProtectedAssets(), _assets / 2, "[0] expect protected liquidity, no interest");

        assertEq(silo1.getLiquidity(), 0, "[1] no liquidity 1");
        assertEq(silo1.getLiquidity(), 0, "[1] no liquidity after deploy 1");
        assertEq(silo1.getProtectedAssets(), 0, "[1] no protected liquidity after deploy 1");
    }

    /*
    forge test -vv --ffi --mt test_liquidity_whenProtected
    */
    function test_liquidity_whenProtected(uint256 _assets) public {
        vm.assume(_assets > 0);

        _deposit(_assets, depositor, ISilo.AssetType.Protected);

        assertEq(silo0.getLiquidity(), 0, "[0] expect liquidity");
        assertEq(silo0.getLiquidity(), 0, "[0] expect no collateral liquidity, no interest");
        assertEq(silo0.getProtectedAssets(), _assets, "[0] expect protected liquidity, no interest");

        assertEq(silo1.getLiquidity(), 0, "[1] no liquidity after deploy 1");
        assertEq(silo1.getLiquidity(), 0, "[1] no collateral liquidity after deploy 1");
        assertEq(silo1.getProtectedAssets(), 0, "[1] no protected liquidity after deploy 1");
    }

    /*
    forge test -vv --ffi --mt test_liquidity_whenDepositAndBorrow
    */
    function test_liquidity_whenDepositAndBorrow(uint128 _toDeposit, uint128 _toBorrow) public {
        vm.assume(_toDeposit > 0);
        vm.assume(_toBorrow > 0);
        vm.assume(_toBorrow < _toDeposit / 2);

        _makeDeposit(silo1, token1, _toDeposit / 2, depositor, ISilo.AssetType.Protected);
        _depositForBorrow(_toDeposit, depositor);

        _deposit(_toDeposit, borrower);
        _borrow(_toBorrow, borrower);

        assertEq(silo0.getLiquidity(), _toDeposit, "[0] expect collateral");
        assertEq(silo0.getLiquidity(), _toDeposit, "[0] expect collateral, no interest");
        assertEq(silo0.getProtectedAssets(), 0, "[0] no protected, no interest");

        assertEq(silo1.getLiquidity(), _toDeposit - _toBorrow, "[1] expect diff after borrow");
        assertEq(silo1.getLiquidity(), _toDeposit - _toBorrow, "[1] expect diff after borrow (interest)");
        assertEq(silo1.getProtectedAssets(), _toDeposit / 2, "[1] expect protected after borrow (interest)");
    }

    /*
    forge test -vv --ffi --mt test_liquidity_whenDepositAndBorrowWithInterest
    */
    function test_liquidity_whenDepositAndBorrowWithInterest(uint128 _toDeposit, uint128 _toBorrow) public {
        vm.assume(_toDeposit > 0);
        vm.assume(_toBorrow > 0);
        vm.assume(_toBorrow < _toDeposit / 2);

        uint256 protectedDeposit0 = _toDeposit / 2;
        uint256 protectedDeposit1 = _toDeposit / 2 + 1;

        _makeDeposit(silo1, token1, protectedDeposit1, depositor, ISilo.AssetType.Protected);
        _depositForBorrow(_toDeposit, depositor);

        _deposit(protectedDeposit0, borrower, ISilo.AssetType.Protected);
        _deposit(_toDeposit, borrower);
        _borrow(_toBorrow, borrower);

        vm.warp(block.timestamp + 100 days);

        uint256 silo0_rawLiquidity = _getRawLiquidity(silo0);
        uint256 silo1_rawLiquidity = _getRawLiquidity(silo1);
        uint256 silo0_liquidityWithInterest = silo0.getLiquidity();
        uint256 silo1_liquidityWithInterest = silo1.getLiquidity();
        uint256 silo0_protectedLiquidity = silo0.getProtectedAssets();
        uint256 silo1_protectedLiquidity = silo1.getProtectedAssets();

        uint256 accruedInterest0 = silo0.accrueInterest();
        assertEq(accruedInterest0, 0, "[0] expect no interest on silo0");

        uint256 accruedInterest1 = silo1.accrueInterest();
        vm.assume(accruedInterest1 > 0);

        assertEq(silo0_rawLiquidity, _toDeposit, "[0] expect same liquidity, because no borrow on this silo");
        assertEq(silo0_liquidityWithInterest, _toDeposit, "[0] same liquidity, no interest");

        assertEq(silo1_rawLiquidity, _toDeposit - _toBorrow, "[1] expect liquidity without counting in interest");
        assertLe(silo1_rawLiquidity, silo0.getLiquidity(), "[1] new liquidity() must not be smaller after interest");

        assertLe(silo0.getLiquidity(), silo0_rawLiquidity, "[0] no interest on silo0, liquidity the same");

        assertEq(
            silo0_liquidityWithInterest,
            _getRawLiquidity(silo0),
            "[0] expect getLiquidity(ISilo.AssetType.Collateral) to be the same as calculated before"
        );

        assertEq(silo0_liquidityWithInterest, silo0_rawLiquidity, "[0] expect no interest");

        assertEq(
            silo0_protectedLiquidity,
            silo0.getProtectedAssets(),
            "[0] expect getProtectedAssets() calculations correct"
        );

        assertEq(silo0_protectedLiquidity, protectedDeposit0, "[0] no interest on protected");

        assertEq(
            silo1_liquidityWithInterest,
            silo1.getLiquidity(),
            "[1] expect getLiquidity() calculations correct"
        );

        assertEq(
            silo1_liquidityWithInterest,
            _getRawLiquidity(silo1),
            "[1] expect getLiquidity(ISilo.AssetType.Collateral) calculations correct"
        );

        assertEq(protectedDeposit1, silo1_protectedLiquidity, "[1] protected liquidity");

        assertEq(
            protectedDeposit1,
            silo1.getProtectedAssets(),
            "[1] protected does not get interest"
        );

        assertLe(
            _getRawLiquidity(silo1),
            silo1_rawLiquidity + accruedInterest1,
            "[1] current liquidity can not be higher that previous + accruedInterest1 because of fees"
        );
    }

    function _getRawLiquidity(ISilo _silo) internal view returns (uint256) {
        return _silo.total(ISilo.AssetType.Collateral) - _silo.total(ISilo.AssetType.Debt);
    }
}
