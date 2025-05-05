// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {IERC20Errors} from "openzeppelin5/interfaces/draft-IERC6093.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {SiloERC4626Lib} from "silo-core/contracts/lib/SiloERC4626Lib.sol";

import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";
import {ShareTokenDecimalsPowLib} from "../../_common/ShareTokenDecimalsPowLib.sol";

/*
    forge test -vv --ffi --mc BorrowSameAssetTest
*/
contract BorrowSameAssetTest is SiloLittleHelper, Test {
    using SiloLensLib for ISilo;
    using ShareTokenDecimalsPowLib for uint256;

    ISiloConfig siloConfig;

    function setUp() public {
        siloConfig = _setUpLocalFixture();

        assertTrue(siloConfig.getConfig(address(silo0)).maxLtv != 0, "we need borrow to be allowed");
    }

    /*
    forge test -vv --ffi --mt test_borrowSameAsset_all_zeros
    */
    function test_borrowSameAsset_all_zeros() public {
        vm.expectRevert(ISilo.InputZeroShares.selector);
        silo0.borrowSameAsset(0, address(0), address(0));
    }

    /*
    forge test -vv --ffi --mt test_borrowSameAsset_zero_assets
    */
    function test_borrowSameAsset_zero_assets() public {
        uint256 assets = 0;
        address borrower = address(1);

        vm.expectRevert(ISilo.InputZeroShares.selector);
        silo0.borrowSameAsset(assets, borrower, borrower);
    }

    /*
    forge test -vv --ffi --mt test_borrowSameAsset_when_NotEnoughLiquidity
    */
    function test_borrowSameAsset_when_NotEnoughLiquidity() public {
        uint256 assets = 1e18;
        address receiver = address(10);

        vm.expectRevert(ISilo.NotEnoughLiquidity.selector);
        silo0.borrowSameAsset(assets, receiver, receiver);
    }

    /*
    forge test -vv --ffi --mt test_borrowSameAsset_max_ltv
    */
    function test_borrowSameAsset_max_ltv() public {
        uint256 assets = 1e18;
        address borrower = address(this);

        _deposit(assets, borrower);

        vm.expectRevert(ISilo.AboveMaxLtv.selector);
        silo0.borrowSameAsset(assets, borrower, borrower);
    }

    /*
    forge test -vv --ffi --mt test_borrowSameAsset_for_receiver_no_collateral
    */
    function test_borrowSameAsset_for_receiver_no_collateral() public {
        uint256 assets = 1e18;
        address borrower = makeAddr("borrower");

        _deposit(assets, makeAddr("depositor"));
        _deposit(assets, borrower, ISilo.CollateralType.Protected);

        uint256 borrowForReceiver = 1;

        vm.expectRevert(abi.encodeWithSelector(IShareToken.AmountExceedsAllowance.selector));
        vm.prank(borrower);
        silo0.borrowSameAsset(borrowForReceiver, borrower, makeAddr("receiver"));
    }

    /*
    forge test -vv --ffi --mt test_borrowSameAsset_onWrongSilo_for_receiver_with_collateral
    */
    function test_borrowSameAsset_onWrongSilo_for_receiver_with_collateral() public {
            uint256 assets = 1e18;
            address borrower = makeAddr("borrower");
            address receiver = makeAddr("receiver");

            _deposit(assets, receiver, ISilo.CollateralType.Protected);

            vm.expectRevert(ISilo.NotEnoughLiquidity.selector);
            vm.prank(borrower);
            silo1.borrowSameAsset(1, borrower, receiver);
    }

    /*
    forge test -vv --ffi --mt test_borrowSameAsset_revert_for_receiver_with_collateral
    */
    function test_borrowSameAsset_revert_for_receiver_with_collateral() public {
        uint256 assets = 1e18;
        address borrower = makeAddr("borrower");
        address receiver = makeAddr("receiver");

        _depositForBorrow(assets, makeAddr("depositor"));
        _deposit(assets, receiver, ISilo.CollateralType.Protected);

        uint256 borrowForReceiver = 1;

        vm.expectRevert(abi.encodeWithSelector(IShareToken.AmountExceedsAllowance.selector));
        vm.prank(borrower);
        silo1.borrowSameAsset(borrowForReceiver, borrower, receiver);
    }

    /*
    forge test -vv --ffi --mt test_borrow_BorrowNotPossible_withDebt
    */
    function test_borrowSameAsset_BorrowNotPossible_withDebt() public {
        uint256 assets = 1e18;
        address borrower = address(this);

        _depositForBorrow(assets, makeAddr("depositor"));
        _deposit(assets, borrower, ISilo.CollateralType.Protected);
        _borrow(1, borrower);

        vm.expectRevert(ISilo.BorrowNotPossible.selector);
        silo0.borrowSameAsset(assets, borrower, borrower);
    }

    /*
    forge test -vv --ffi --mt test_borrowSameAsset_frontRun_pass_1token
    */
    function test_borrowSameAsset_frontRun_pass_1token() public {
        uint256 assets = 1e18;
        address borrower = address(this);

        _deposit(assets, makeAddr("depositor"));
        _deposit(assets, borrower, ISilo.CollateralType.Protected);

        vm.prank(makeAddr("frontrunner"));
        _deposit(1, borrower);

        vm.prank(borrower);
        silo0.borrowSameAsset(12345, borrower, borrower);
    }

    /*
    forge test -vv --ffi --mt test_borrowSameAsset_frontRun_transferShare
    */
    function test_borrowSameAsset_frontRun_transferShare() public {
        uint256 assets = 1e18;
        address borrower = makeAddr("borrower");
        address frontrunner = makeAddr("frontrunner");

        _deposit(assets, makeAddr("depositor"));
        _deposit(assets, borrower, ISilo.CollateralType.Protected);

        (
            address protectedShareToken, address collateralShareToken,
        ) = siloConfig.getShareTokens(address(silo0));

        _depositCollateral(5, frontrunner, false);
        _depositCollateral(3, frontrunner, false, ISilo.CollateralType.Protected);

        vm.prank(frontrunner);
        IShareToken(collateralShareToken).transfer(borrower, 5);
        vm.prank(frontrunner);
        IShareToken(protectedShareToken).transfer(borrower, 3);

        vm.prank(borrower); // frontrun does not work
        silo0.borrowSameAsset(12345, borrower, borrower);
    }

    /*
    forge test -vv --ffi --mt test_borrowSameAsset_withTwoCollaterals
    */
    function test_borrowSameAsset_withTwoCollaterals() public {
        uint256 assets = 1e18;
        address borrower = address(this);

        _deposit(assets, makeAddr("depositor"));

        uint256 notCollateral = 123;
        _depositCollateral(notCollateral, borrower, true /* to silo1 */);
        _deposit(assets, borrower, ISilo.CollateralType.Protected);

        vm.expectEmit(address(silo0));
        emit ISilo.CollateralTypeChanged(borrower);

        vm.prank(borrower);
        silo0.borrowSameAsset(1234, borrower, borrower);
    }

    /*
    forge test -vv --ffi --mt test_borrowSameAsset_pass
    */
    function test_borrowSameAsset_pass() public {
        uint256 depositAssets = 1e18;
        address borrower = makeAddr("Borrower");
        address depositor = makeAddr("Depositor");

        _deposit(depositAssets, depositor);
        _deposit(depositAssets, borrower);

        (,, address debtShareToken) = siloConfig.getShareTokens(address(silo0));

        uint256 maxBorrow = silo0.maxBorrowSameAsset(borrower);
        // -2 because of the fractions underestimation
        assertEq(maxBorrow, 0.75e18 - 1, "invalid maxBorrow for two tokens");

        uint256 borrowToMuch = maxBorrow + 2;
        emit log_named_uint("borrowToMuch", borrowToMuch);

        vm.expectRevert(ISilo.AboveMaxLtv.selector);
        vm.prank(borrower);
        silo0.borrowSameAsset(borrowToMuch, borrower, borrower);

        vm.prank(borrower);
        silo0.borrowSameAsset(maxBorrow, borrower, borrower);

        (,, address otherSiloDebtShareToken) = siloConfig.getShareTokens(address(silo1));

        assertEq(
            IShareToken(otherSiloDebtShareToken).balanceOf(borrower),
            0,
            "expect borrower to NOT have debt in other silo"
        );

        assertEq(silo1.getDebtAssets(), 0, "expect other silo to NOT have debt");

        assertEq(IShareToken(debtShareToken).balanceOf(borrower), maxBorrow, "expect borrower to have debt");
        assertEq(silo0.getDebtAssets(), maxBorrow, "expect debt silo to have debt");
    }

    /*
    forge test -vv --ffi --mt test_borrowSameAsset_twice
    */
    function test_borrowSameAsset_twice() public {
        uint256 depositAssets = 1e18;
        address depositor = makeAddr("Depositor");
        address borrower = makeAddr("Borrower");

        _deposit(depositAssets, borrower);
        // deposit, so we can borrow
        _deposit(depositAssets * 2, depositor);

        (, address collateralShareToken, address debtShareToken) = siloConfig.getShareTokens(address(silo0));

        assertEq(
            IShareToken(collateralShareToken).balanceOf(borrower),
            depositAssets.decimalsOffsetPow(),
            "expect borrower to have collateral"
        );

        _borrowSameAssetWithAssertions(borrower, debtShareToken, collateralShareToken);
        vm.expectRevert(ISilo.AboveMaxLtv.selector);
        vm.prank(borrower);
        silo0.borrowSameAsset(0.0001e18, borrower, borrower);
    }

    /*
    forge test -vv --ffi --mt test_borrowSameAsset_scenarios
    */
    function test_borrowSameAsset_scenarios() public {
        uint256 depositAssets = 1e18;
        address borrower = address(0x22334455);
        address depositor = address(0x9876123);
        uint256 expectedLtv = 0.75e18;

        _deposit(depositAssets, borrower, ISilo.CollateralType.Collateral);

        // deposit, so we can borrow
        _deposit(100e18, depositor);

        assertEq(silo0.getLtv(borrower), 0, "no debt, so LT == 0 (silo0)");
        assertEq(silo1.getLtv(borrower), 0, "no debt, so LT == 0 (silo1)");

        uint256 maxBorrow = silo0.maxBorrowSameAsset(borrower) + 1; // +1 to balance out underestimation

        vm.expectRevert(ISilo.NotEnoughLiquidity.selector);
        vm.prank(borrower);
        silo0.borrowSameAsset(200e18, borrower, borrower);

        vm.expectRevert(ISilo.AboveMaxLtv.selector);
        vm.prank(borrower);
        silo0.borrowSameAsset(depositAssets * 2, borrower, borrower);

        vm.prank(borrower);
        silo0.borrowSameAsset(maxBorrow / 2, borrower, borrower);

        assertEq(silo0.getLtv(borrower), expectedLtv / 2, "borrow 50% of max, maxLTV is 75%, so LT == 37,5% (silo0)");
        assertEq(silo1.getLtv(borrower), expectedLtv / 2, "borrow 50% of max, maxLTV is 75%, so LT == 37,5% (silo1)");

        assertEq(silo1.maxBorrowSameAsset(borrower), 0, "maxBorrow 0");
        assertTrue(silo0.isSolvent(borrower), "still isSolvent (silo0)");
        assertTrue(silo1.isSolvent(borrower), "still isSolvent (silo1)");

        vm.expectRevert(ISilo.BorrowNotPossible.selector);
        vm.prank(borrower);
        silo1.borrowSameAsset(1, borrower, borrower);
    }

    function _borrowSameAssetWithAssertions(
        address _borrower,
        address _debtShareToken,
        address _collateralToken
    ) private {
        uint256 maxLtv = 0.75e18;

        uint256 maxBorrow = silo1.maxBorrow(_borrower);
        assertEq(maxBorrow, 0, "maxBorrow should be 0, because we don't have collateral there");

        maxBorrow = silo0.maxBorrowSameAsset(_borrower);
        emit log_named_decimal_uint("maxBorrow #1", maxBorrow, 18);
        // -1 because of the fractions underestimation
        assertEq(maxBorrow, maxLtv - 1, "maxBorrow borrower can do, maxLTV is 75%");

        uint256 borrowAmount = maxBorrow / 2;
        emit log_named_decimal_uint("first borrow amount", borrowAmount, 18);

        uint256 convertToShares = silo0.convertToShares(borrowAmount, ISilo.AssetType.Debt);
        uint256 previewBorrowShares = silo0.previewBorrowShares(convertToShares);
        assertEq(previewBorrowShares, borrowAmount, "previewBorrowShares crosscheck");

        vm.prank(_borrower);
        uint256 gotShares = silo0.borrowSameAsset(borrowAmount, _borrower, _borrower);
        uint256 shareTokenCurrentDebt = maxLtv / 2;

        uint256 expectedShares = 1e18;
        expectedShares = expectedShares.decimalsOffsetPow();

        assertEq(IShareToken(_debtShareToken).balanceOf(_borrower), shareTokenCurrentDebt - 1, "expect borrower to have 1/2 of debt");
        assertEq(IShareToken(_collateralToken).balanceOf(_borrower), expectedShares, "borrower has collateral");
        assertEq(silo0.getDebtAssets(), shareTokenCurrentDebt - 1, "silo debt");
        assertEq(gotShares, shareTokenCurrentDebt - 1, "got debt shares");
        assertEq(gotShares, convertToShares, "convertToShares returns same result");
        assertEq(borrowAmount, silo0.convertToAssets(gotShares, ISilo.AssetType.Debt), "convertToAssets returns borrowAmount");

        borrowAmount = silo0.maxBorrowSameAsset(_borrower);
        emit log_named_decimal_uint("borrowAmount #2", borrowAmount, 18);
        assertEq(borrowAmount, maxLtv / 2 - 2, "borrow second time"); // -2 because of the fractions underestimation

        convertToShares = silo0.convertToShares(borrowAmount, ISilo.AssetType.Debt);

        vm.prank(_borrower);
        gotShares = silo0.borrowSameAsset(borrowAmount, _borrower, _borrower);

        assertEq(IShareToken(_debtShareToken).balanceOf(_borrower), maxLtv - 3, "debt silo: borrower has debt");
        assertEq(gotShares, maxLtv / 2 - 2, "got shares"); // -2 because of the fractions underestimation
        assertEq(silo0.getDebtAssets(), maxBorrow - 2, "debt silo: has debt"); // -2 because of the fractions underestimation
        assertEq(gotShares, convertToShares, "convertToShares returns same result (2)");
        assertEq(borrowAmount, silo0.convertToAssets(gotShares, ISilo.AssetType.Debt), "convertToAssets returns borrowAmount (2)");

        // other silo
        (,, _debtShareToken) = siloConfig.getShareTokens(address(silo1));

        assertEq(
            IShareToken(_debtShareToken).balanceOf(_borrower),
            0,
            "other silo: expect borrower NOT have debt"
        );

        assertEq(
            IShareToken(_collateralToken).balanceOf(_borrower),
            expectedShares,
            "collateral silo: borrower has collateral"
        );

        assertEq(silo1.getDebtAssets(), 0, "other silo: NO debt");

        assertTrue(silo0.isSolvent(_borrower), "still isSolvent (silo0)");
        assertTrue(silo1.isSolvent(_borrower), "still isSolvent (silo1)");
    }
}
