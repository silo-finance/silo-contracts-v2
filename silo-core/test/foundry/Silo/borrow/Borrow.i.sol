// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {IERC20Errors} from "openzeppelin5/interfaces/draft-IERC6093.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {SiloERC4626Lib} from "silo-core/contracts/lib/SiloERC4626Lib.sol";
import {AssetTypes} from "silo-core/contracts/lib/AssetTypes.sol";

import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc BorrowIntegrationTest
*/
contract BorrowIntegrationTest is SiloLittleHelper, Test {
    using SiloLensLib for ISilo;

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
        silo0.borrow(0, address(0), address(0), TWO_ASSETS);

        vm.expectRevert(ISilo.ZeroAssets.selector);
        silo0.borrow(0, address(0), address(0), SAME_ASSET);
    }

    /*
    forge test -vv --ffi --mt test_borrow_zero_assets
    */
    function test_borrow_zero_assets() public {
        uint256 assets = 0;
        address borrower = address(1);

        vm.expectRevert(ISilo.ZeroAssets.selector);
        silo0.borrow(assets, borrower, borrower, SAME_ASSET);

        vm.expectRevert(ISilo.ZeroAssets.selector);
        silo0.borrow(assets, borrower, borrower, TWO_ASSETS);
    }

    /*
    forge test -vv --ffi --mt test_borrow_when_NotEnoughLiquidity
    */
    function test_borrow_when_NotEnoughLiquidity() public {
        uint256 assets = 1e18;
        address receiver = address(10);

        vm.expectRevert(ISilo.NotEnoughLiquidity.selector);
        silo0.borrow(assets, receiver, receiver, SAME_ASSET);

        vm.expectRevert(ISilo.NotEnoughLiquidity.selector);
        silo0.borrow(assets, receiver, receiver, TWO_ASSETS);
    }

    /*
    forge test -vv --ffi --mt test_borrow_when_frontRun_NoCollateral
    */
    function test_borrow_when_frontRun_NoCollateral_1token() public {
        _borrow_when_frontRun_NoCollateral(SAME_ASSET);
    }

    function test_borrow_when_frontRun_NoCollateral_2tokens() public {
        _borrow_when_frontRun_NoCollateral(TWO_ASSETS);
    }

    function _borrow_when_frontRun_NoCollateral(bool _sameAsset) private {
        uint256 assets = 1e18;
        address borrower = address(this);

        // frontrun on other silo
        _depositCollateral(assets, borrower, !_sameAsset);

        vm.expectRevert(_sameAsset ? ISilo.NotEnoughLiquidity.selector : ISilo.AboveMaxLtv.selector);
        silo1.borrow(assets, borrower, borrower, _sameAsset);
    }

    /*
    forge test -vv --ffi --mt test_borrow_onWrongSilo_for_receiver_no_collateral_
    */
    function test_borrow_onWrongSilo_for_receiver_no_collateral_1token() public {
        _borrow_onWrongSilo_for_receiver_no_collateral(SAME_ASSET);
    }

    function test_borrow_onWrongSilo_for_receiver_no_collateral_2tokens() public {
        _borrow_onWrongSilo_for_receiver_no_collateral(TWO_ASSETS);
    }

    function _borrow_onWrongSilo_for_receiver_no_collateral(bool _sameAsset) private {
        uint256 assets = 1e18;
        address borrower = makeAddr("borrower");

        _deposit(assets, makeAddr("depositor"));
        _depositCollateral(assets, borrower, _sameAsset, ISilo.CollateralType.Protected);

        uint256 borrowForReceiver = 1;

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, borrower, 0, borrowForReceiver)
        ); // because we want to mint for receiver
        vm.prank(borrower);
        silo0.borrow(borrowForReceiver, borrower, makeAddr("receiver"), _sameAsset);
    }

    /*
    forge test -vv --ffi --mt test_borrow_onWrongSilo_for_receiver_with_collateral_
    */
    function test_borrow_onWrongSilo_for_receiver_with_collateral_1token() public {
        _borrow_onWrongSilo_for_receiver_with_collateral(SAME_ASSET);
    }

    function test_borrow_onWrongSilo_for_receiver_with_collateral_2tokens() public {
        _borrow_onWrongSilo_for_receiver_with_collateral(TWO_ASSETS);
    }

    function _borrow_onWrongSilo_for_receiver_with_collateral(bool _sameAsset) private {
        uint256 assets = 1e18;
        address borrower = makeAddr("borrower");
        address receiver = makeAddr("receiver");

        _depositCollateral(assets, receiver, _sameAsset, ISilo.CollateralType.Protected);

        vm.expectRevert(ISilo.NotEnoughLiquidity.selector);
        vm.prank(borrower);
        silo0.borrow(1, borrower, receiver, _sameAsset);
    }

    /*
    forge test -vv --ffi --mt test_borrow_revert_for_receiver_with_collateral_
    */
    function test_borrow_revert_for_receiver_with_collateral_1token() public {
        _borrow_revert_for_receiver_with_collateral(SAME_ASSET);
    }

    function test_borrow_revert_for_receiver_with_collateral_2tokens() public {
        _borrow_revert_for_receiver_with_collateral(TWO_ASSETS);
    }

    function _borrow_revert_for_receiver_with_collateral(bool _sameAsset) private {
        uint256 assets = 1e18;
        address borrower = makeAddr("borrower");
        address receiver = makeAddr("receiver");

        _depositForBorrow(assets, makeAddr("depositor"));
        _depositCollateral(assets, receiver, _sameAsset, ISilo.CollateralType.Protected);

        uint256 borrowForReceiver = 1;

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, borrower, 0, borrowForReceiver)
        ); // because we want to mint for receiver
        vm.prank(borrower);
        silo1.borrow(borrowForReceiver, borrower, receiver, _sameAsset);
    }

    /*
    forge test -vv --ffi --mt test_borrow_onWrongSilo_for_borrower
    */
    function test_borrow_onWrongSilo_for_borrower_1token() public {
        _borrow_onWrongSilo_for_borrower(SAME_ASSET);
    }

    function test_borrow_onWrongSilo_for_borrower_2tokens() public {
        _borrow_onWrongSilo_for_borrower(TWO_ASSETS);
    }

    function _borrow_onWrongSilo_for_borrower(bool _sameAsset) private {
        uint256 assets = 1e18;
        address borrower = makeAddr("borrower");

        _depositCollateral(assets, makeAddr("depositor"), !_sameAsset);
        _depositCollateral(assets, borrower, _sameAsset, ISilo.CollateralType.Collateral);

        vm.expectCall(address(token0), abi.encodeWithSelector(IERC20.transfer.selector, borrower, assets));

        vm.expectRevert(ISilo.AboveMaxLtv.selector);
        vm.prank(borrower);
        silo0.borrow(assets, borrower, borrower, _sameAsset);
    }

    /*
    forge test -vv --ffi --mt test_borrow_onWrongSilo_WithProtected
    */
    function test_borrow_onWrongSilo_WithProtected_1token() public {
        _borrow_onWrongSilo_WithProtected(SAME_ASSET);
    }

    function test_borrow_onWrongSilo_WithProtected_2tokens() public {
        _borrow_onWrongSilo_WithProtected(TWO_ASSETS);
    }

    function _borrow_onWrongSilo_WithProtected(bool _sameAsset) private {
        uint256 assets = 1e18;
        address borrower = address(this);

        _depositCollateral(assets, borrower, _sameAsset, ISilo.CollateralType.Protected);

        vm.expectRevert(ISilo.NotEnoughLiquidity.selector);
        silo0.borrow(assets, borrower, borrower, _sameAsset);
    }

    /*
    forge test -vv --ffi --mt test_borrow_onWrongSilo_WithCollateralAndProtected
    */
    function test_borrow_onWrongSilo_WithCollateralAndProtected_1token() public {
        _borrow_onWrongSilo_WithCollateralAndProtected(SAME_ASSET);
    }

    function test_borrow_onWrongSilo_WithCollateralAndProtected_2tokens() public {
        _borrow_onWrongSilo_WithCollateralAndProtected(TWO_ASSETS);
    }

    function _borrow_onWrongSilo_WithCollateralAndProtected(bool _sameAsset) private {
        uint256 assets = 1e18;
        address borrower = address(this);

        _depositCollateral(assets * 2, borrower, _sameAsset, ISilo.CollateralType.Protected);
        _depositCollateral(assets, borrower, _sameAsset);

        vm.expectRevert(_sameAsset ? ISilo.NotEnoughLiquidity.selector : ISilo.AboveMaxLtv.selector);
        silo0.borrow(assets, borrower, borrower, _sameAsset);
    }

    /*
    forge test -vv --ffi --mt test_borrow_BorrowNotPossible_withDebt
    */
    function test_borrow_BorrowNotPossible_withDebt_1token() public {
        _borrow_BorrowNotPossible_withDebt(SAME_ASSET);
    }

    function test_borrow_BorrowNotPossible_withDebt_2tokens() public {
        _borrow_BorrowNotPossible_withDebt(TWO_ASSETS);
    }

    function _borrow_BorrowNotPossible_withDebt(bool _sameAsset) private {
        uint256 assets = 1e18;
        address borrower = address(this);

        _depositForBorrow(assets, makeAddr("depositor"));
        _depositCollateral(assets, borrower, _sameAsset, ISilo.CollateralType.Protected);
        _borrow(1, borrower, _sameAsset);

        vm.expectRevert(ISilo.BorrowNotPossible.selector);
        silo0.borrow(assets, borrower, borrower, _sameAsset);
    }

    /*
    forge test -vv --ffi --mt test_borrow_frontRun_pass
    */
    function test_borrow_frontRun_pass_1token() public {
        _borrow_frontRun_pass(SAME_ASSET);
    }

    function test_borrow_frontRun_pass_2tokens() public {
        _borrow_frontRun_pass(TWO_ASSETS);
    }

    function _borrow_frontRun_pass(bool _sameAsset) private {
        uint256 assets = 1e18;
        address borrower = address(this);

        _depositForBorrow(assets, makeAddr("depositor"));
        _depositCollateral(assets, borrower, _sameAsset, ISilo.CollateralType.Protected);

        vm.prank(makeAddr("frontrunner"));
        _depositCollateral(1, borrower, !_sameAsset);

        _borrow(12345, borrower, _sameAsset);
    }

    /*
    forge test -vv --ffi --mt test_borrow_frontRun_transferShare
    */
    function test_borrow_frontRun_transferShare_1token() public {
        _borrow_frontRun_transferShare(SAME_ASSET);
    }

    function test_borrow_frontRun_transferShare_2token() public {
        _borrow_frontRun_transferShare(TWO_ASSETS);
    }

    function _borrow_frontRun_transferShare(bool _sameAsset) private {
        uint256 assets = 1e18;
        address borrower = address(this);
        address frontrunner = makeAddr("frontrunner");

        _depositForBorrow(assets, makeAddr("depositor"));
        _depositCollateral(assets, borrower, _sameAsset, ISilo.CollateralType.Protected);

        (
            address protectedShareToken, address collateralShareToken,
        ) = siloConfig.getShareTokens(address(_sameAsset ? silo0 : silo1));

        _depositCollateral(5, frontrunner, !_sameAsset);
        _depositCollateral(3, frontrunner, !_sameAsset, ISilo.CollateralType.Protected);

        vm.prank(frontrunner);
        IShareToken(collateralShareToken).transfer(borrower, 5);
        vm.prank(frontrunner);
        IShareToken(protectedShareToken).transfer(borrower, 3);

        _borrow(12345, borrower, _sameAsset); // frontrun does not work
    }

    /*
    forge test -vv --ffi --mt test_borrow_withTwoCollaterals
    */
    function test_borrow_withTwoCollaterals_1token() public {
        _borrow_withTwoCollaterals(SAME_ASSET);
    }

    function test_borrow_withTwoCollaterals_2tokens() public {
        _borrow_withTwoCollaterals(TWO_ASSETS);
    }

    function _borrow_withTwoCollaterals(bool _sameAsset) private {
        uint256 assets = 1e18;
        address borrower = address(this);

        _depositForBorrow(assets, makeAddr("depositor"));

        uint256 notCollateral = 123;
        _depositCollateral(notCollateral, borrower, !_sameAsset);
        _depositCollateral(assets, borrower, _sameAsset, ISilo.CollateralType.Protected);

        _borrow(12345, borrower, _sameAsset);
    }

    /*
    forge test -vv --ffi --mt test_borrow_pass
    */
    function test_borrow_pass_1token() public {
        _borrow_pass(SAME_ASSET);
    }

    function test_borrow_pass_2tokens() public {
        _borrow_pass(TWO_ASSETS);
    }

    function _borrow_pass(bool _sameAsset) private {
        uint256 depositAssets = 1e18;
        address borrower = makeAddr("Borrower");
        address depositor = makeAddr("Depositor");

        _depositForBorrow(depositAssets, depositor);
        _depositCollateral(depositAssets, borrower, _sameAsset);

        (
            address protectedShareToken, address collateralShareToken, address debtShareToken
        ) = siloConfig.getShareTokens(address(silo0));

        uint256 maxBorrow = silo1.maxBorrow(borrower, _sameAsset);
        uint256 maxBorrowShares = silo1.maxBorrowShares(borrower, _sameAsset);

        if (_sameAsset) {
            assertEq(maxBorrow, 0.85e18 - 1, "invalid maxBorrow for sameAsset");
            assertEq(maxBorrowShares, 0.85e18, "invalid maxBorrowShares for sameAsset");
        } else {
            assertEq(maxBorrow, 0.75e18 - 1, "invalid maxBorrow for two tokens");
            assertEq(maxBorrowShares, 0.75e18, "invalid maxBorrowShares for two tokens");
        }

        uint256 borrowToMuch = maxBorrow + 2;
        // emit log_named_uint("borrowToMuch", borrowToMuch);

        vm.expectRevert(ISilo.AboveMaxLtv.selector);
        vm.prank(borrower);
        silo1.borrow(borrowToMuch, borrower, borrower, _sameAsset);

        _borrow(maxBorrow, borrower, _sameAsset);

        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 0, "expect borrower to NOT have debt in collateral silo");
        assertEq(silo0.getDebtAssets(), 0, "expect collateral silo to NOT have debt");

        (protectedShareToken, collateralShareToken, debtShareToken) = siloConfig.getShareTokens(address(silo1));
        assertEq(IShareToken(debtShareToken).balanceOf(borrower), maxBorrow, "expect borrower to have debt in debt silo");
        assertEq(silo1.getDebtAssets(), maxBorrow, "expect debt silo to have debt");
    }

    /*
    forge test -vv --ffi --mt test_borrow_twice
    */
    function test_borrow_twice_1token() public {
        _borrow_twice(SAME_ASSET);
    }

    function test_borrow_twice_2tokens() public {
        _borrow_twice(TWO_ASSETS);
    }

    function _borrow_twice(bool _sameAsset) private {
        uint256 depositAssets = 1e18;
        address borrower = address(0x22334455);
        address depositor = address(0x9876123);
        uint256 maxLtv = _sameAsset ? 0.85e18 : 0.75e18;

        _depositCollateral(depositAssets, borrower, _sameAsset);

        (, address collateralShareToken,) = siloConfig.getShareTokens(address(_sameAsset ? silo1 : silo0));
        (,, address debtShareToken) = siloConfig.getShareTokens(address(silo1));

        assertEq(IShareToken(collateralShareToken).balanceOf(borrower), depositAssets, "expect borrower to have collateral");

        uint256 maxBorrow = silo0.maxBorrow(borrower, _sameAsset);
        assertEq(maxBorrow, 0, "maxBorrow should be 0, because this is where collateral is");

        // deposit, so we can borrow
        _depositForBorrow(depositAssets * 2, depositor);

        // in this particular scenario max borrow is underestimated by 1, so we compensate by +1, to max out
        maxBorrow = silo1.maxBorrow(borrower, _sameAsset) + 1;
        emit log_named_decimal_uint("maxBorrow #1", maxBorrow, 18);
        assertEq(maxBorrow, maxLtv, "maxBorrow borrower can do, maxLTV is 75%");

        uint256 borrowAmount = maxBorrow / 2;
        emit log_named_decimal_uint("first borrow amount", borrowAmount, 18);

        uint256 convertToShares = silo1.convertToShares(borrowAmount);
        uint256 previewBorrowShares = silo1.previewBorrowShares(convertToShares);
        assertEq(previewBorrowShares, borrowAmount, "previewBorrowShares crosscheck");

        uint256 gotShares = _borrow(borrowAmount, borrower, _sameAsset);
        uint256 shareTokenCurrentDebt = maxLtv / 2;

        assertEq(IShareToken(debtShareToken).balanceOf(borrower), shareTokenCurrentDebt, "expect borrower to have 1/2 of debt");
        assertEq(IShareToken(collateralShareToken).balanceOf(borrower), 1e18, "collateral silo: borrower has collateral");
        assertEq(silo1.getDebtAssets(), shareTokenCurrentDebt, "silo debt");
        assertEq(gotShares, shareTokenCurrentDebt, "got debt shares");
        assertEq(gotShares, convertToShares, "convertToShares returns same result");
        assertEq(borrowAmount, silo1.convertToAssets(gotShares), "convertToAssets returns borrowAmount");

        // in this particular scenario max borrow is underestimated by 1, so we compensate by +1, to max out
        borrowAmount = silo1.maxBorrow(borrower, _sameAsset) + 1;
        emit log_named_decimal_uint("borrowAmount #2", borrowAmount, 18);
        assertEq(borrowAmount, maxLtv / 2, "borrow second time");

        convertToShares = silo1.convertToShares(borrowAmount);
        gotShares = _borrow(borrowAmount, borrower, _sameAsset);

        assertEq(IShareToken(debtShareToken).balanceOf(borrower), maxLtv, "debt silo: borrower has debt");
        assertEq(gotShares, maxLtv / 2, "got shares");
        assertEq(silo1.getDebtAssets(), maxBorrow, "debt silo: has debt");
        assertEq(gotShares, convertToShares, "convertToShares returns same result (2)");
        assertEq(borrowAmount, silo1.convertToAssets(gotShares), "convertToAssets returns borrowAmount (2)");

        // collateral silo
        (,, debtShareToken) = siloConfig.getShareTokens(address(_sameAsset ? silo1 : silo0));

        if (!_sameAsset) {
            assertEq(
                IShareToken(debtShareToken).balanceOf(borrower),
                0,
                "collateral silo: expect borrower NOT have debt"
            );
        }

        assertEq(IShareToken(collateralShareToken).balanceOf(borrower), 1e18, "collateral silo: borrower has collateral");
        assertEq(silo0.getDebtAssets(), 0, "collateral silo: NO debt");

        assertTrue(silo0.isSolvent(borrower), "still isSolvent (silo0)");
        assertTrue(silo1.isSolvent(borrower), "still isSolvent (silo1)");

        _borrow(0.0001e18, borrower, _sameAsset, ISilo.AboveMaxLtv.selector);
    }

    /*
    forge test -vv --ffi --mt test_borrow_scenarios
    */
    function test_borrow_scenarios_1token() public {
        _borrow_scenarios(SAME_ASSET);
    }

    function test_borrow_scenarios_2tokens() public {
        _borrow_scenarios(TWO_ASSETS);
    }

    function _borrow_scenarios(bool _sameAsset) private {
        uint256 depositAssets = 1e18;
        address borrower = address(0x22334455);
        address depositor = address(0x9876123);
        uint256 expectedLtv = _sameAsset ? 0.85e18 : 0.75e18;

        _depositCollateral(depositAssets, borrower, _sameAsset, ISilo.CollateralType.Collateral);

        // deposit, so we can borrow
        _depositForBorrow(100e18, depositor);
        assertEq(silo0.getLtv(borrower), 0, "no debt, so LT == 0 (silo0)");
        assertEq(silo1.getLtv(borrower), 0, "no debt, so LT == 0 (silo1)");

        uint256 maxBorrow = silo1.maxBorrow(borrower, _sameAsset) + 1; // +1 to balance out underestimation

        _borrow(200e18, borrower, _sameAsset, ISilo.NotEnoughLiquidity.selector);
        _borrow(maxBorrow * 2, borrower, _sameAsset, ISilo.AboveMaxLtv.selector);
        _borrow(maxBorrow / 2, borrower, _sameAsset);
        assertEq(silo0.getLtv(borrower), expectedLtv / 2, "borrow 50% of max, maxLTV is 75%, so LT == 37,5% (silo0)");
        assertEq(silo1.getLtv(borrower), expectedLtv / 2, "borrow 50% of max, maxLTV is 75%, so LT == 37,5% (silo1)");

        _borrow(200e18, borrower, _sameAsset, ISilo.NotEnoughLiquidity.selector);
        _borrow(maxBorrow, borrower, _sameAsset, ISilo.AboveMaxLtv.selector);
        _borrow(maxBorrow / 2, borrower, _sameAsset);
        assertEq(silo0.getLtv(borrower), expectedLtv, "borrow 100% of max, so LT == 75% (silo0)");
        assertEq(silo1.getLtv(borrower), expectedLtv, "borrow 100% of max, so LT == 75% (silo1)");

        assertEq(silo0.maxBorrow(borrower, _sameAsset), 0, "maxBorrow 0");
        assertTrue(silo0.isSolvent(borrower), "still isSolvent (silo0)");
        assertTrue(silo1.isSolvent(borrower), "still isSolvent (silo1)");
        assertTrue(silo1.borrowPossible(borrower), "borrow is still possible, we just reached CAP");

        _borrow(1, borrower, _sameAsset, ISilo.AboveMaxLtv.selector);
    }

    /*
    forge test -vv --ffi --mt test_borrow_maxDeposit
    */
    function test_borrow_maxDeposit_1token() public {
        _borrow_maxDeposit(SAME_ASSET);
    }

    function test_borrow_maxDeposit_2tokens() public {
        _borrow_maxDeposit(TWO_ASSETS);
    }

    function _borrow_maxDeposit(bool _sameAsset) private {
        address borrower = makeAddr("Borrower");
        address depositor = makeAddr("depositor");

        _depositCollateral(10, borrower, _sameAsset);
        _depositForBorrow(1, depositor);
        _borrow(1, borrower, _sameAsset);

        uint256 silo1TotalCollateral = _sameAsset ? 10 + 1 : 1;

        assertEq(
            SiloERC4626Lib._VIRTUAL_DEPOSIT_LIMIT - silo1TotalCollateral,
            SiloERC4626Lib._VIRTUAL_DEPOSIT_LIMIT - silo1.total(AssetTypes.COLLATERAL),
            "limit for deposit"
        );

        assertEq(
            silo1.maxDeposit(borrower),
            SiloERC4626Lib._VIRTUAL_DEPOSIT_LIMIT - silo1.total(AssetTypes.COLLATERAL),
            "can deposit when already borrowed"
        );

        assertEq(
            silo1.maxMint(borrower),
            SiloERC4626Lib._VIRTUAL_DEPOSIT_LIMIT - silo1.total(AssetTypes.COLLATERAL),
            "can mint when already borrowed (maxMint)"
        );
    }

    /*
    forge test -vv --ffi --mt test_borrowShares_revertsOnZeroAssets
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_borrowShares_revertsOnZeroAssets_1token_fuzz(uint256 _depositAmount, uint256 _forBorrow) public {
        _borrowShares_revertsOnZeroAssets(_depositAmount, _forBorrow, SAME_ASSET);
    }

    /// forge-config: core-test.fuzz.runs = 1000
    function test_borrowShares_revertsOnZeroAssets_2tokens_fuzz(uint256 _depositAmount, uint256 _forBorrow) public {
        _borrowShares_revertsOnZeroAssets(_depositAmount, _forBorrow, TWO_ASSETS);
    }

    function _borrowShares_revertsOnZeroAssets(uint256 _depositAmount, uint256 _forBorrow, bool _sameAsset) private {
        vm.assume(_depositAmount > _forBorrow);
        vm.assume(_forBorrow > 0);

        if (_sameAsset) {
            vm.assume(type(uint256).max - _depositAmount > _forBorrow);
        }

        address borrower = makeAddr("Borrower");
        address depositor = makeAddr("depositor");

        _depositCollateral(_depositAmount, borrower, _sameAsset);
        _depositForBorrow(_forBorrow, depositor);
        uint256 amount = _borrowShares(1, borrower, _sameAsset);

        assertGt(amount, 0, "amount can never be 0");
    }

    function _borrow(uint256 _amount, address _borrower, bool _sameAsset, bytes4 _revert) internal returns (uint256 shares) {
        vm.expectRevert(_revert);
        vm.prank(_borrower);
        shares = silo1.borrow(_amount, _borrower, _borrower, _sameAsset);
    }
}
