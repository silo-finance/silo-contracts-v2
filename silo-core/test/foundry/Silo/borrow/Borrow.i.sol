// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {SiloERC4626Lib} from "silo-core/contracts/lib/SiloERC4626Lib.sol";

import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc BorrowIntegrationTest
*/
contract BorrowIntegrationTest is SiloLittleHelper, Test {
    using SiloLensLib for ISilo;

    ISiloConfig siloConfig;
    bool sameToken;

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

        vm.expectRevert(ISilo.ZeroAssets.selector);
        silo0.borrow(0, address(0), address(0), true /* sameToken */);
    }

    /*
    forge test -vv --ffi --mt test_borrow_zero_assets
    */
    function test_borrow_zero_assets() public {
        uint256 assets = 0;
        address borrower = address(1);

        vm.expectRevert(ISilo.ZeroAssets.selector);
        silo0.borrow(assets, borrower, borrower, true);

        vm.expectRevert(ISilo.ZeroAssets.selector);
        silo0.borrow(assets, borrower, borrower, false);
    }

    /*
    forge test -vv --ffi --mt test_borrow_when_NotEnoughLiquidity
    */
    function test_borrow_when_NotEnoughLiquidity() public {
        uint256 assets = 1e18;
        address receiver = address(10);

        vm.expectRevert(ISilo.NotEnoughLiquidity.selector);
        silo0.borrow(assets, receiver, receiver, true);

        vm.expectRevert(ISilo.NotEnoughLiquidity.selector);
        silo0.borrow(assets, receiver, receiver, false);
    }

    /*
    forge test -vv --ffi --mt test_borrow_when_frontRun_NoCollateral
    */
    function test_borrow_when_frontRun_NoCollateral_1token() public {
        _borrow_when_frontRun_NoCollateral(true);
    }

    function test_borrow_when_frontRun_NoCollateral_2tokens() public {
        _borrow_when_frontRun_NoCollateral(false);
    }

    function _borrow_when_frontRun_NoCollateral(bool _sameToken) private {
        uint256 assets = 1e18;
        address borrower = address(this);

        // frontrun on other silo
        _depositCollateral(assets, borrower, !_sameToken);

        vm.expectRevert(_sameToken ? ISilo.NotEnoughLiquidity.selector : ISilo.AboveMaxLtv.selector);
        silo1.borrow(assets, borrower, borrower, _sameToken);
    }

    /*
    forge test -vv --ffi --mt test_borrow_onWrongSilo_for_receiver_no_collateral_
    */
    function test_borrow_onWrongSilo_for_receiver_no_collateral_1token() public {
        _borrow_onWrongSilo_for_receiver_no_collateral(true);
    }

    function test_borrow_onWrongSilo_for_receiver_no_collateral_2tokens() public {
        _borrow_onWrongSilo_for_receiver_no_collateral(false);
    }

    function _borrow_onWrongSilo_for_receiver_no_collateral(bool _sameToken) public {
        uint256 assets = 1e18;
        address borrower = makeAddr("borrower");

        _depositForBorrow(assets, makeAddr("depositor"));
        // !_sameToken to move collateral to wrong silo
        _depositCollateral(assets, borrower, _sameToken, ISilo.AssetType.Protected);

        // there will be no withdraw because we borrow for receiver and receiver has no collateral

        vm.expectRevert("ERC20: insufficient allowance"); // because we want to mint for receiver
        vm.prank(borrower);
        silo0.borrow(1, borrower, makeAddr("receiver"), _sameToken);
    }

    /*
    forge test -vv --ffi --mt test_borrow_onWrongSilo_for_receiver_with_collateral_
    */
    function test_borrow_onWrongSilo_for_receiver_with_collateral_1token() public {
        _borrow_onWrongSilo_for_receiver_with_collateral(true);
    }

    function test_borrow_onWrongSilo_for_receiver_with_collateral_2tokens() public {
        _borrow_onWrongSilo_for_receiver_with_collateral(false);
    }

    function _borrow_onWrongSilo_for_receiver_with_collateral(bool _sameToken) private {
        uint256 assets = 1e18;
        address borrower = makeAddr("borrower");
        address receiver = makeAddr("receiver");

        _depositCollateral(assets, receiver, _sameToken, ISilo.AssetType.Protected);

        vm.expectRevert(ISilo.NotEnoughLiquidity.selector);
        vm.prank(borrower);
        silo0.borrow(1, borrower, receiver, _sameToken);
    }

    /*
    forge test -vv --ffi --mt test_borrow_revert_for_receiver_with_collateral_
    */
    function test_borrow_revert_for_receiver_with_collateral_1token() public {
        _borrow_revert_for_receiver_with_collateral(true);
    }

    function test_borrow_revert_for_receiver_with_collateral_2tokens() public {
        _borrow_revert_for_receiver_with_collateral(false);
    }

    function _borrow_revert_for_receiver_with_collateral(bool _sameToken) private {
        uint256 assets = 1e18;
        address borrower = makeAddr("borrower");
        address receiver = makeAddr("receiver");

        _depositForBorrow(assets, makeAddr("depositor"));
        _depositCollateral(assets, receiver, _sameToken, ISilo.AssetType.Protected);

        vm.expectRevert("ERC20: insufficient allowance"); // because we want to mint for receiver
        vm.prank(borrower);
        silo1.borrow(1, borrower, receiver, _sameToken);
    }

    /*
    forge test -vv --ffi --mt test_borrow_onWrongSilo_for_borrower
    */
    function test_borrow_onWrongSilo_for_borrower_1token() public {
        _borrow_onWrongSilo_for_borrower(true);
    }

    function test_borrow_onWrongSilo_for_borrower_2tokens() public {
        _borrow_onWrongSilo_for_borrower(false);
    }

    function _borrow_onWrongSilo_for_borrower(bool _sameToken) private {
        uint256 assets = 1e18;
        address borrower = makeAddr("borrower");

        _depositCollateral(assets, makeAddr("depositor"), !_sameToken);
        _depositCollateral(assets, borrower, _sameToken, ISilo.AssetType.Collateral);

        vm.expectCall(address(token0), abi.encodeWithSelector(IERC20.transfer.selector, borrower, assets));

        vm.expectRevert(ISilo.AboveMaxLtv.selector);
        vm.prank(borrower);
        silo0.borrow(assets, borrower, borrower, _sameToken);
    }

    /*
    forge test -vv --ffi --mt test_borrow_onWrongSilo_WithProtected
    */
    function test_borrow_onWrongSilo_WithProtected_1token() public {
        _borrow_onWrongSilo_WithProtected(true);
    }

    function test_borrow_onWrongSilo_WithProtected_2tokens() public {
        _borrow_onWrongSilo_WithProtected(false);
    }

    function _borrow_onWrongSilo_WithProtected(bool _sameToken) private {
        uint256 assets = 1e18;
        address borrower = address(this);

        _depositCollateral(assets, borrower, _sameToken, ISilo.AssetType.Protected);

        vm.expectRevert(ISilo.NotEnoughLiquidity.selector);
        silo0.borrow(assets, borrower, borrower, _sameToken);
    }

    /*
    forge test -vv --ffi --mt test_borrow_onWrongSilo_WithCollateralAndProtected
    */
    function test_borrow_onWrongSilo_WithCollateralAndProtected_1token() public {
        _borrow_onWrongSilo_WithCollateralAndProtected(true);
    }

    function test_borrow_onWrongSilo_WithCollateralAndProtected_2tokens() public {
        _borrow_onWrongSilo_WithCollateralAndProtected(false);
    }

    function _borrow_onWrongSilo_WithCollateralAndProtected(bool _sameToken) private {
        uint256 assets = 1e18;
        address borrower = address(this);

        _depositCollateral(assets * 2, borrower, _sameToken, ISilo.AssetType.Protected);
        _depositCollateral(assets, borrower, _sameToken);

        vm.expectRevert(_sameToken ? ISilo.NotEnoughLiquidity.selector : ISilo.AboveMaxLtv.selector);
        silo0.borrow(assets, borrower, borrower, _sameToken);
    }

    /*
    forge test -vv --ffi --mt test_borrow_BorrowNotPossible_withDebt
    */
    function test_borrow_BorrowNotPossible_withDebt_1token() public {
        _borrow_BorrowNotPossible_withDebt(true);
    }

    function test_borrow_BorrowNotPossible_withDebt_2tokens() public {
        _borrow_BorrowNotPossible_withDebt(false);
    }

    function _borrow_BorrowNotPossible_withDebt(bool _sameToken) private {
        uint256 assets = 1e18;
        address borrower = address(this);

        _depositForBorrow(assets, makeAddr("depositor"));
        _depositCollateral(assets, borrower, _sameToken, ISilo.AssetType.Protected);
        _borrow(1, borrower, _sameToken);

        vm.expectRevert(ISilo.BorrowNotPossible.selector);
        silo0.borrow(assets, borrower, borrower, _sameToken);
    }

    /*
    forge test -vv --ffi --mt test_borrow_frontRun_pass
    */
    function test_borrow_frontRun_pass_1token() public {
        _borrow_frontRun_pass(true);
    }

    function test_borrow_frontRun_pass_2tokens() public {
        _borrow_frontRun_pass(false);
    }

    function _borrow_frontRun_pass(bool _sameToken) private {
        uint256 assets = 1e18;
        address borrower = address(this);

        _depositForBorrow(assets, makeAddr("depositor"));
        _depositCollateral(assets, borrower, _sameToken, ISilo.AssetType.Protected);

        vm.prank(makeAddr("frontrunner"));
        _depositCollateral(1, borrower, !_sameToken);

        _borrow(12345, borrower, _sameToken);
    }

    /*
    forge test -vv --ffi --mt test_borrow_frontRun_transferShare
    */
    function test_borrow_frontRun_transferShare_1token() public {
        _borrow_frontRun_transferShare(true);
    }

    function test_borrow_frontRun_transferShare_2token() public {
        _borrow_frontRun_transferShare(false);
    }

    function _borrow_frontRun_transferShare(bool _sameToken) private {
        uint256 assets = 1e18;
        address borrower = address(this);
        address frontrunner = makeAddr("frontrunner");

        _depositForBorrow(assets, makeAddr("depositor"));
        _depositCollateral(assets, borrower, _sameToken, ISilo.AssetType.Protected);

        (
            address protectedShareToken, address collateralShareToken,
        ) = siloConfig.getShareTokens(address(_sameToken ? silo0 : silo1));

        _depositCollateral(5, frontrunner, !_sameToken);
        _depositCollateral(3, frontrunner, !_sameToken, ISilo.AssetType.Protected);

        vm.prank(frontrunner);
        IShareToken(collateralShareToken).transfer(borrower, 5);
        vm.prank(frontrunner);
        IShareToken(protectedShareToken).transfer(borrower, 3);

        _borrow(12345, borrower, _sameToken); // frontrun does not work
    }

    /*
    forge test -vv --ffi --mt test_borrow_withTwoCollaterals
    */
    function test_borrow_withTwoCollaterals_1token() public {
        _borrow_withTwoCollaterals(true);
    }

    function test_borrow_withTwoCollaterals_2tokens() public {
        _borrow_withTwoCollaterals(false);
    }

    function _borrow_withTwoCollaterals(bool _sameToken) private {
        uint256 assets = 1e18;
        address borrower = address(this);

        _depositForBorrow(assets, makeAddr("depositor"));

        uint256 notCollateral = 123;
        _depositCollateral(notCollateral, borrower, !_sameToken);
        _depositCollateral(assets, borrower, _sameToken, ISilo.AssetType.Protected);

        _borrow(12345, borrower, _sameToken);
    }

    /*
    forge test -vv --ffi --mt test_borrow_pass
    */
    function test_borrow_pass_1token() public {
        _borrow_pass(true);
    }

    function test_borrow_pass_2tokens() public {
        _borrow_pass(false);
    }

    function _borrow_pass(bool _sameToken) private {
        uint256 depositAssets = 1e18;
        address borrower = makeAddr("Borrower");
        address depositor = makeAddr("Depositor");

        _depositForBorrow(depositAssets, depositor);
        _depositCollateral(depositAssets, borrower, _sameToken);

        (
            address protectedShareToken, address collateralShareToken, address debtShareToken
        ) = siloConfig.getShareTokens(address(silo0));

        uint256 maxBorrow = silo1.maxBorrow(borrower, _sameToken);
        uint256 maxBorrowShares = silo1.maxBorrowShares(borrower, _sameToken);

        if (_sameToken) {
            assertEq(maxBorrow, 0.85e18 - 1, "invalid maxBorrow for sameToken");
            assertEq(maxBorrowShares, 0.85e18, "invalid maxBorrowShares for sameToken");
        } else {
            assertEq(maxBorrow, 0.75e18 - 1, "invalid maxBorrow for two tokens");
            assertEq(maxBorrowShares, 0.75e18, "invalid maxBorrowShares for two tokens");
        }

        uint256 borrowToMuch = maxBorrow + 2;
        // emit log_named_uint("borrowToMuch", borrowToMuch);

        vm.expectRevert(ISilo.AboveMaxLtv.selector);
        vm.prank(borrower);
        silo1.borrow(borrowToMuch, borrower, borrower, _sameToken);

        _borrow(maxBorrow, borrower, _sameToken);

        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 0, "expect borrower to NOT have debt in collateral silo");
        assertEq(silo0.getDebtAssets(), 0, "expect collateral silo to NOT have debt");

        (protectedShareToken, collateralShareToken, debtShareToken) = siloConfig.getShareTokens(address(silo1));
        assertEq(IShareToken(debtShareToken).balanceOf(borrower), maxBorrow, "expect borrower to have debt in debt silo");
        assertEq(silo1.getDebtAssets(), maxBorrow, "expect debt silo to have debt");
    }

    /*
    forge test -vv --ffi --mt test_borrow_twice
    */
    function test_borrow_twice_fuzz() public {
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

        uint256 gotShares = _borrow(borrowAmount, borrower, sameToken);
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
        gotShares = _borrow(borrowAmount, borrower, sameToken);

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

        _borrow(0.0001e18, borrower, sameToken, ISilo.AboveMaxLtv.selector);
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

        _borrow(200e18, borrower, sameToken, ISilo.NotEnoughLiquidity.selector);
        _borrow(maxBorrow * 2, borrower, sameToken, ISilo.AboveMaxLtv.selector);
        _borrow(maxBorrow / 2, borrower, sameToken);
        assertEq(silo1.getLtv(borrower), 0.375e18, "borrow 50% of max, and maxLTV is 75%, so LT == 37,5%");

        _borrow(200e18, borrower, sameToken, ISilo.NotEnoughLiquidity.selector);
        _borrow(maxBorrow, borrower, sameToken, ISilo.AboveMaxLtv.selector);
        _borrow(maxBorrow / 2, borrower, sameToken);
        assertEq(silo1.getLtv(borrower), 0.75e18, "borrow 100% of max, so LT == 75%%");

        assertEq(silo0.maxBorrow(borrower, sameToken), 0, "maxBorrow 0");
        assertTrue(silo0.isSolvent(borrower), "still isSolvent");
        assertTrue(silo1.isSolvent(borrower), "still isSolvent");
        assertTrue(silo1.borrowPossible(borrower), "borrow is still possible, we just reached CAP");

        _borrow(1, borrower, sameToken, ISilo.AboveMaxLtv.selector);
    }

    /*
    forge test -vv --ffi --mt test_borrow_maxDeposit
    */
    function test_borrow_maxDeposit() public {
        address borrower = makeAddr("Borrower");
        address depositor = makeAddr("depositor");

        _deposit(10, borrower);
        _depositForBorrow(1, depositor);
        _borrow(1, borrower, sameToken);

        assertEq(
            SiloERC4626Lib._VIRTUAL_DEPOSIT_LIMIT - 1,
            SiloERC4626Lib._VIRTUAL_DEPOSIT_LIMIT - silo1.total(ISilo.AssetType.Collateral),
            "limit for deposit"
        );

        assertEq(
            silo1.maxDeposit(borrower),
            SiloERC4626Lib._VIRTUAL_DEPOSIT_LIMIT - silo1.total(ISilo.AssetType.Collateral),
            "can deposit when already borrowed"
        );

        assertEq(
            silo1.maxMint(borrower),
            SiloERC4626Lib._VIRTUAL_DEPOSIT_LIMIT - silo1.total(ISilo.AssetType.Collateral),
            "can mint when already borrowed (maxMint)"
        );
    }

    /*
    forge test -vv --ffi --mt test_borrowShares_revertsOnZeroAssets
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_borrowShares_revertsOnZeroAssets_fuzz(uint256 _depositAmount, uint256 _forBorrow) public {
        vm.assume(_depositAmount > _forBorrow);
        vm.assume(_forBorrow > 0);

        address borrower = makeAddr("Borrower");
        address depositor = makeAddr("depositor");

        _deposit(_depositAmount, borrower);
        _depositForBorrow(_forBorrow, depositor);
        uint256 amount = _borrowShares(1, borrower, sameToken);

        assertGt(amount, 0, "amount can never be 0");
    }

    function _borrow(uint256 _amount, address _borrower, bool _sameToken, bytes4 _revert) internal returns (uint256 shares) {
        vm.expectRevert(_revert);
        vm.prank(_borrower);
        shares = silo1.borrow(_amount, _borrower, _borrower, _sameToken);
    }
}
