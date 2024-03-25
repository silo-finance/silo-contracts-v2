// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";

import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc BorrowIntegrationTest
*/
contract BorrowIntegrationTest is SiloLittleHelper, Test {
    using SiloLensLib for ISilo;

    ISiloConfig siloConfig;
    bool sameToken = false;

    function setUp() public {
        siloConfig = _setUpLocalFixture();

        assertTrue(siloConfig.getConfig(address(silo0)).maxLtv != 0, "we need borrow to be allowed");
    }

    /*
    forge test -vv --ffi --mt test_borrow_all_zeros
    */
    function test_borrow_all_zeros() public {
        vm.expectRevert(ISilo.ZeroAssets.selector);
        silo0.borrow(0, address(0), address(0), false /* sameToken */);
    }

    /*
    forge test -vv --ffi --mt test_borrow_zero_assets
    */
    function test_borrow_zero_assets() public {
        uint256 assets = 0;
        address borrower = address(1);

        vm.expectRevert(ISilo.ZeroAssets.selector);
        silo0.borrow(assets, borrower, borrower, sameToken);
    }

    /*
    forge test -vv --ffi --mt test_borrow_when_NotEnoughLiquidity
    */
    function test_borrow_when_NotEnoughLiquidity() public {
        uint256 assets = 1e18;
        address receiver = address(10);

        vm.expectRevert(ISilo.NotEnoughLiquidity.selector);
        silo0.borrow(assets, receiver, receiver, sameToken);
    }

    /*
    forge test -vv --ffi --mt test_borrow_when_frontRun_NoCollateral
    */
    function test_borrow_when_frontRun_NoCollateral() public {
        uint256 assets = 1e18;
        address receiver = address(this);

        _deposit(assets, receiver, ISilo.AssetType.Collateral);

        vm.expectCall(address(token0), abi.encodeWithSelector(IERC20.transfer.selector, address(receiver), assets));

        vm.expectRevert(ISilo.NotEnoughLiquidity.selector);
        silo0.borrow(assets, receiver, receiver, sameToken);
    }

    /*
    forge test -vv --ffi --mt test_borrow_onWrongSilo_for_receiver
    */
    function test_borrow_onWrongSilo_for_receiver_no_collateral() public {
        uint256 assets = 1e18;
        address borrower = makeAddr("borrower");

        _deposit(assets, makeAddr("depositor"), ISilo.AssetType.Collateral);
        _deposit(assets, borrower, ISilo.AssetType.Protected);

        // there will be no withdraw because we borrow for receiver and receiver has no collateral

        vm.expectRevert("ERC20: insufficient allowance"); // because we want to mint for receiver
        vm.prank(borrower);
        silo0.borrow(assets, borrower, makeAddr("receiver"), sameToken);
    }

    /*
    forge test -vv --ffi --mt test_borrow_onWrongSilo_for_receiver_with_collateral
    */
    function test_borrow_onWrongSilo_for_receiver_with_collateral() public {
        uint256 assets = 1e18;
        address borrower = makeAddr("borrower");
        address receiver = makeAddr("receiver");

        _deposit(assets, makeAddr("depositor"), ISilo.AssetType.Collateral);
        _deposit(assets, receiver, ISilo.AssetType.Protected);

        vm.expectCall(address(token0), abi.encodeWithSelector(IERC20.transfer.selector, receiver, assets));

        vm.expectRevert("ERC20: insufficient allowance"); // because we want to mint for receiver
        vm.prank(borrower);
        silo0.borrow(assets, borrower, makeAddr("receiver"), sameToken);
    }

    /*
    forge test -vv --ffi --mt test_borrow_onWrongSilo_for_borrower
    */
    function test_borrow_onWrongSilo_for_borrower() public {
        uint256 assets = 1e18;
        address borrower = makeAddr("borrower");

        _deposit(assets, makeAddr("depositor"), ISilo.AssetType.Collateral);
        _deposit(assets, borrower, ISilo.AssetType.Collateral);

        vm.expectCall(address(token0), abi.encodeWithSelector(IERC20.transfer.selector, borrower, assets));

        vm.expectRevert(ISilo.AboveMaxLtv.selector);
        vm.prank(borrower);
        silo0.borrow(assets, borrower, borrower, sameToken);
    }

    /*
    forge test -vv --ffi --mt test_borrow_onWrongSilo_WithProtected
    */
    function test_borrow_onWrongSilo_WithProtected() public {
        uint256 assets = 1e18;
        address borrower = address(this);

        _deposit(assets, borrower, ISilo.AssetType.Protected);

        vm.expectCall(address(token0), abi.encodeWithSelector(IERC20.transfer.selector, borrower, assets));

        vm.expectRevert(ISilo.NotEnoughLiquidity.selector);
        silo0.borrow(assets, borrower, borrower, sameToken);
    }

    /*
    forge test -vv --ffi --mt test_borrow_onWrongSilo_WithCollateralAndProtected
    */
    function test_borrow_onWrongSilo_WithCollateralAndProtected() public {
        uint256 assets = 1e18;
        address borrower = address(this);

        _deposit(assets * 2, borrower, ISilo.AssetType.Protected);
        _deposit(assets, borrower, ISilo.AssetType.Collateral);

        vm.expectCall(address(token0), abi.encodeWithSelector(IERC20.transfer.selector, borrower, assets));
        vm.expectCall(address(token0), abi.encodeWithSelector(IERC20.transfer.selector, borrower, assets * 2));

        vm.expectRevert(ISilo.NotEnoughLiquidity.selector);
        silo0.borrow(assets, borrower, borrower, sameToken);
    }

    /*
    forge test -vv --ffi --mt test_borrow_BorrowNotPossible_withDebt
    */
    function test_borrow_BorrowNotPossible_withDebt() public {
        uint256 assets = 1e18;
        address borrower = address(this);

        _depositForBorrow(assets, makeAddr("depositor"));
        _deposit(assets, borrower, ISilo.AssetType.Protected);
        _borrow(1, borrower);

        vm.expectRevert(ISilo.BorrowNotPossible.selector);
        silo0.borrow(assets, borrower, borrower, sameToken);
    }

    /*
    forge test -vv --ffi --mt test_borrow_frontRun_pass
    */
    function test_borrow_frontRun_pass() public {
        uint256 assets = 1e18;
        address borrower = address(this);

        _depositForBorrow(assets, makeAddr("depositor"));
        _deposit(assets, borrower, ISilo.AssetType.Protected);

        vm.prank(makeAddr("frontrunner"));
        _depositForBorrow(1, borrower);

        vm.expectCall(address(token1), abi.encodeWithSelector(IERC20.transfer.selector, borrower, 1));

        _borrow(12345, borrower);
    }

    /*
    forge test -vv --ffi --mt test_borrow_frontRun_transferShare
    */
    function test_borrow_frontRun_transferShare() public {
        uint256 assets = 1e18;
        address borrower = address(this);
        address frontrunner = makeAddr("frontrunner");

        _depositForBorrow(assets, makeAddr("depositor"));
        _deposit(assets, borrower, ISilo.AssetType.Protected);

        (address protectedShareToken, address collateralShareToken,) = siloConfig.getShareTokens(address(silo1));
        _depositForBorrow(5, frontrunner);
        _makeDeposit(silo1, token1, 3, frontrunner, ISilo.AssetType.Protected);

        vm.prank(frontrunner);
        IShareToken(protectedShareToken).transfer(borrower, 3);
        vm.prank(frontrunner);
        IShareToken(collateralShareToken).transfer(borrower, 5);

        vm.expectCall(address(token1), abi.encodeWithSelector(IERC20.transfer.selector, borrower, 3));
        vm.expectCall(address(token1), abi.encodeWithSelector(IERC20.transfer.selector, borrower, 5));

        _borrow(12345, borrower);
    }

    /*
    forge test -vv --ffi --mt test_borrow_withTwoCollaterals
    */
    function test_borrow_withTwoCollaterals() public {
        uint256 assets = 1e18;
        address borrower = address(this);

        _depositForBorrow(assets, makeAddr("depositor"));

        uint256 toWithdraw = 123;
        _depositForBorrow(toWithdraw, borrower);
        _deposit(assets, borrower, ISilo.AssetType.Protected);

        vm.expectCall(address(token1), abi.encodeWithSelector(IERC20.transfer.selector, borrower, toWithdraw));

        _borrow(12345, borrower);
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

        uint256 maxBorrow = silo0.maxBorrow(borrower, sameToken);
        uint256 maxBorrowShares = silo0.maxBorrowShares(borrower, sameToken);
        assertEq(maxBorrow, 0.85e18 - 1, "invalid maxBorrow");
        assertEq(maxBorrowShares, 0.85e18, "invalid maxBorrowShares");

        uint256 borrowToMuch = maxBorrow + 2;
        // emit log_named_uint("borrowToMuch", borrowToMuch);

        vm.expectRevert(ISilo.AboveMaxLtv.selector);
        vm.prank(borrower);
        silo0.borrow(borrowToMuch, borrower, borrower, sameToken);

        vm.prank(borrower);
        silo0.borrow(maxBorrow, borrower, borrower, sameToken);

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

        uint256 maxBorrow = silo0.maxBorrow(borrower, sameToken);
        assertEq(maxBorrow, 0, "maxBorrow should be 0, because this is where collateral is");

        // deposit, so we can borrow
        _depositForBorrow(depositAssets * 2, depositor);

        // in this particular scenario max borrow is underestimated by 1, so we compensate by +1, to max out
        maxBorrow = silo1.maxBorrow(borrower, sameToken) + 1;
        emit log_named_decimal_uint("maxBorrow #1", maxBorrow, 18);
        assertEq(maxBorrow, 0.75e18, "maxBorrow borrower can do, maxLTV is 75%");

        uint256 borrowAmount = maxBorrow / 2;
        emit log_named_decimal_uint("first borrow amount", borrowAmount, 18);

        uint256 convertToShares = silo1.convertToShares(borrowAmount);
        uint256 previewBorrowShares = silo1.previewBorrowShares(convertToShares);
        assertEq(previewBorrowShares, borrowAmount, "previewBorrowShares crosscheck");

        uint256 gotShares = _borrow(borrowAmount, borrower);
        uint256 shareTokenCurrentDebt = 0.375e18;

        assertEq(IShareToken(debtShareToken).balanceOf(borrower), shareTokenCurrentDebt, "expect borrower to have 1/2 of debt");
        assertEq(IShareToken(collateralShareToken).balanceOf(borrower), 1e18, "collateral silo: borrower has collateral");
        assertEq(silo1.getDebtAssets(), shareTokenCurrentDebt, "silo debt");
        assertEq(gotShares, shareTokenCurrentDebt, "got debt shares");
        assertEq(gotShares, convertToShares, "convertToShares returns same result");
        assertEq(borrowAmount, silo1.convertToAssets(gotShares), "convertToAssets returns borrowAmount");

        // in this particular scenario max borrow is underestimated by 1, so we compensate by +1, to max out
        borrowAmount = silo1.maxBorrow(borrower, sameToken) + 1;
        emit log_named_decimal_uint("borrowAmount #2", borrowAmount, 18);
        assertEq(borrowAmount, 0.75e18 / 2, "borrow second time");

        convertToShares = silo1.convertToShares(borrowAmount);
        gotShares = _borrow(borrowAmount, borrower);

        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 0.75e18, "debt silo: borrower has debt");
        assertEq(gotShares, 0.375e18, "got shares");
        assertEq(silo1.getDebtAssets(), maxBorrow, "debt silo: has debt");
        assertEq(gotShares, convertToShares, "convertToShares returns same result (2)");
        assertEq(borrowAmount, silo1.convertToAssets(gotShares), "convertToAssets returns borrowAmount (2)");

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

        // deposit, so we can borrow
        _depositForBorrow(100e18, depositor);
        assertEq(silo1.getLtv(borrower), 0, "no debt, so LT == 0");

        uint256 maxBorrow = silo1.maxBorrow(borrower, sameToken) + 1; // +1 to balance out underestimation

        _borrow(200e18, borrower, ISilo.NotEnoughLiquidity.selector);
        _borrow(maxBorrow * 2, borrower, ISilo.AboveMaxLtv.selector);
        _borrow(maxBorrow / 2, borrower);
        assertEq(silo1.getLtv(borrower), 0.375e18, "borrow 50% of max, and maxLTV is 75%, so LT == 37,5%");

        _borrow(200e18, borrower, ISilo.NotEnoughLiquidity.selector);
        _borrow(maxBorrow, borrower, ISilo.AboveMaxLtv.selector);
        _borrow(maxBorrow / 2, borrower);
        assertEq(silo1.getLtv(borrower), 0.75e18, "borrow 100% of max, so LT == 75%%");

        assertEq(silo0.maxBorrow(borrower, sameToken), 0, "maxBorrow 0");
        assertTrue(silo0.isSolvent(borrower), "still isSolvent");
        assertTrue(silo1.isSolvent(borrower), "still isSolvent");
        assertTrue(silo1.borrowPossible(borrower), "borrow is still possible, we just reached CAP");

        _borrow(1, borrower, ISilo.AboveMaxLtv.selector);
    }

    /*
    forge test -vv --ffi --mt test_borrow_maxDeposit
    */
    function test_borrow_maxDeposit() public {
        address borrower = makeAddr("Borrower");
        address depositor = makeAddr("depositor");

        _deposit(10, borrower);
        _depositForBorrow(1, depositor);
        _borrow(1, borrower);

        assertEq(silo1.maxDeposit(borrower), 0, "can not deposit when already borrowed");
        assertEq(silo1.maxMint(borrower), 0, "can not mint when already borrowed (maxMint)");
    }

    /*
    forge test -vv --ffi --mt test_borrowShares_revertsOnZeroAssets
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_borrowShares_revertsOnZeroAssets_fuzz(uint256 _depositAmount, uint256 _forBorrow) public {
        vm.assume(_depositAmount > _forBorrow);
        vm.assume(_forBorrow > 0);

        address borrower = makeAddr("Borrower");
        address depositor = makeAddr("depositor");

        _deposit(_depositAmount, borrower);
        _depositForBorrow(_forBorrow, depositor);
        uint256 amount = _borrowShares(1, borrower);

        assertGt(amount, 0, "amount can never be 0");
    }

    function _borrow(uint256 _amount, address _borrower, bytes4 _revert) internal returns (uint256 shares) {
        vm.expectRevert(_revert);
        vm.prank(_borrower);
        shares = silo1.borrow(_amount, _borrower, _borrower, sameToken);
    }
}
