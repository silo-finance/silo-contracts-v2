// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc BorrowTest
*/
contract BorrowTest is SiloLittleHelper, Test {
    ISiloConfig siloConfig;

    function setUp() public {
        siloConfig = _setUpLocalFixture();

        assertTrue(siloConfig.getConfig(address(silo0)).maxLtv != 0, "we need borrow to be allowed");
    }

    /*
    forge test -vv --ffi --mt test_borrow_all_zeros
    */
    function test_borrow_all_zeros() public {
        vm.expectRevert(ISilo.ZeroAssets.selector);
        silo0.borrow(0, address(0), address(0));
    }

    /*
    forge test -vv --ffi --mt test_borrow_zero_assets
    */
    function test_borrow_zero_assets() public {
        uint256 assets = 0;
        address borrower = address(1);

        vm.expectRevert(ISilo.ZeroAssets.selector);
        silo0.borrow(assets, borrower, borrower);
    }

    /*
    forge test -vv --ffi --mt test_borrow_when_NotEnoughLiquidity
    */
    function test_borrow_when_NotEnoughLiquidity() public {
        uint256 assets = 1e18;
        address receiver = address(10);

        vm.expectRevert(ISilo.NotEnoughLiquidity.selector);
        silo0.borrow(assets, receiver, receiver);
    }

    /*
    forge test -vv --ffi --mt test_borrow_when_BorrowNotPossible_withCollateral
    */
    function test_borrow_when_BorrowNotPossible_withCollateral() public {
        uint256 assets = 1e18;
        address receiver = address(10);

        _deposit(assets, receiver, ISilo.AssetType.Collateral);

        vm.expectRevert(ISilo.BorrowNotPossible.selector);
        silo0.borrow(assets, receiver, receiver);
    }

    /*
    forge test -vv --ffi --mt test_borrow_when_BorrowNotPossible_withProtected
    */
    function test_borrow_when_BorrowNotPossible_withProtected() public {
        uint256 assets = 1e18;
        address receiver = address(10);

        _deposit(assets, receiver, ISilo.AssetType.Protected);

        vm.expectRevert(ISilo.BorrowNotPossible.selector);
        silo0.borrow(assets, receiver, receiver);
    }

    /*
    forge test -vv --ffi --mt test_borrow_pass
    */
    function test_borrow_pass() public {
        uint256 depositAssets = 1e18;
        address borrower = makeAddr("Borrower");
        address depositor = makeAddr("Depositor");

        _deposit(depositAssets, depositor, ISilo.AssetType.Collateral);
        _depositForBorrow(depositAssets, borrower);

        (address protectedShareToken, address collateralShareToken, address debtShareToken) = siloConfig.getShareTokens(address(silo1));
        assertGt(IShareToken(collateralShareToken).balanceOf(borrower), 0, "expect borrower to have collateral");

        uint256 maxBorrow = silo0.maxBorrow(borrower);
        assertEq(maxBorrow, 0.85e18, "invalid maxBorrow");

        uint256 borrowToMuch = maxBorrow + 1;
        // emit log_named_uint("borrowToMuch", borrowToMuch);

        vm.expectRevert(ISilo.AboveMaxLtv.selector);
        vm.prank(borrower);
        silo0.borrow(borrowToMuch, borrower, borrower);

        vm.prank(borrower);
        silo0.borrow(maxBorrow, borrower, borrower);

        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 0, "expect borrower to NOT have debt in collateral silo");
        assertEq(silo1.getDebtAssets(), 0, "expect collateral silo to NOT have debt");

        (protectedShareToken, collateralShareToken, debtShareToken) = siloConfig.getShareTokens(address(silo0));
        assertEq(IShareToken(debtShareToken).balanceOf(borrower), maxBorrow, "expect borrower to have debt in debt silo");
        assertEq(silo0.getDebtAssets(), maxBorrow, "expect debt silo to have debt");
    }

    /*
    forge test -vv --ffi --mt test_borrow_twice
    */
    function test_borrow_twice() public {
        uint256 depositAssets = 1e18;
        address borrower = address(0x22334455);
        address depositor = address(0x9876123);

        _deposit(depositAssets, borrower);

        (address protectedShareToken, address collateralShareToken,) = siloConfig.getShareTokens(address(silo0));
        (,, address debtShareToken) = siloConfig.getShareTokens(address(silo1));
        assertEq(IShareToken(collateralShareToken).balanceOf(borrower), depositAssets, "expect borrower to have collateral");

        uint256 maxBorrow = silo0.maxBorrow(borrower);
        assertEq(maxBorrow, 0, "maxBorrow should be 0 because this is where collateral is");

        maxBorrow = silo1.maxBorrow(borrower);
        // emit log_named_decimal_uint("maxBorrow #1", maxBorrow, 18);
        assertEq(maxBorrow, 0.75e18, "maxBorrow borrower can do, maxLTV is 75%");

        // deposit, so we can borrow
        _depositForBorrow(maxBorrow * 2, depositor);

        uint256 borrowAmount = maxBorrow / 2;
        // emit log_named_decimal_uint("borrowAmount", borrowAmount, 18);

        uint256 gotShares = _borrow(borrowAmount, borrower);

        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 0.375e18, "expect borrower to have 1/2 of debt");
        assertEq(IShareToken(collateralShareToken).balanceOf(borrower), 1e18, "collateral silo: borrower has collateral");
        assertEq(silo1.getDebtAssets(), 0.375e18, "silo debt");
        assertEq(gotShares, 0.375e18, "got debt shares");

        borrowAmount = silo1.maxBorrow(borrower);
        // emit log_named_decimal_uint("borrowAmount #2", borrowAmount, 18);
        assertEq(borrowAmount, 0.75e18 / 2, "~");

        gotShares = _borrow(borrowAmount, borrower);

        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 0.75e18, "debt silo: borrower has debt");
        assertEq(gotShares, 0.375e18, "got shares");
        assertEq(silo1.getDebtAssets(), maxBorrow, "debt silo: has debt");

        // collateral silo
        (protectedShareToken, collateralShareToken, debtShareToken) = siloConfig.getShareTokens(address(silo0));
        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 0, "collateral silo: expect borrower to NOT have debt");
        assertEq(IShareToken(collateralShareToken).balanceOf(borrower), 1e18, "collateral silo: borrower has collateral");
        assertEq(silo0.getDebtAssets(), 0, "collateral silo: NO debt");

        assertTrue(silo0.isSolvent(borrower), "still isSolvent");
        assertTrue(silo1.isSolvent(borrower), "still isSolvent");

        _borrow(0.0001e18, borrower, ISilo.AboveMaxLtv.selector);
    }

    /*
    forge test -vv --ffi --mt test_borrow_scenarios
    */
    function test_borrow_scenarios() public {
        uint256 depositAssets = 1e18;
        address borrower = address(0x22334455);
        address depositor = address(0x9876123);

        _deposit(depositAssets, borrower, ISilo.AssetType.Collateral);

        uint256 maxBorrow = silo1.maxBorrow(borrower);

        // deposit, so we can borrow
        _depositForBorrow(100e18, depositor);

        _borrow(200e18, borrower, ISilo.NotEnoughLiquidity.selector);
        _borrow(maxBorrow * 2, borrower, ISilo.AboveMaxLtv.selector);
        _borrow(maxBorrow / 2, borrower);

        _borrow(200e18, borrower, ISilo.NotEnoughLiquidity.selector);
        _borrow(maxBorrow, borrower, ISilo.AboveMaxLtv.selector);
        _borrow(maxBorrow / 2, borrower);

        assertEq(silo0.maxBorrow(borrower), 0, "maxBorrow 0");
        assertTrue(silo0.isSolvent(borrower), "still isSolvent");
        assertTrue(silo1.isSolvent(borrower), "still isSolvent");

        _borrow(1, borrower, ISilo.AboveMaxLtv.selector);
    }

    function _borrow(uint256 _amount, address _borrower, bytes4 _revert) internal returns (uint256 shares) {
        vm.expectRevert(_revert);
        vm.prank(_borrower);
        shares = silo1.borrow(_amount, _borrower, _borrower);
    }
}
