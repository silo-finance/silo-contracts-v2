// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IERC20Errors} from "openzeppelin5/interfaces/draft-IERC6093.sol";

import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc RepayTest
*/
contract RepayTest is SiloLittleHelper, Test {
    ISiloConfig siloConfig;

    function setUp() public {
        siloConfig = _setUpLocalFixture();
    }

    /*
    forge test -vv --ffi --mt test_repay_zeros
    */
    function test_repay_zeros() public {
        vm.expectRevert(ISilo.ZeroAssets.selector);
        silo0.repay(0, address(0));
    }

    /*
    forge test -vv --ffi --mt test_repay_fromZeroAddress
    */
    function test_repay_fromZeroAddress() public {
        // for some reason we not bale to check for this error: Error != expected error: NH{q != Arithmetic over/underflow
        vm.expectRevert();
        silo0.repay(1, address(0));
    }

    /*
    forge test -vv --ffi --mt test_repay_whenNoDebt
    */
    function test_repay_whenNoDebt() public {
        address borrower = address(this);
        uint256 amount = 1;

        token0.mint(address(this), amount);
        token0.approve(address(silo0), amount);
        // for some reason we not bale to check for this error: Error != expected error: NH{q != Arithmetic over/underflow
        vm.expectRevert(); // "Arithmetic over/underflow";
        silo0.repay(amount, borrower);
    }

    /*
    forge test -vv --ffi --mt test_repay_throwZeroShares
    */
    function test_repay_throwZeroShares_1token() public {
        _repay_throwZeroShares();
    }

    function _repay_throwZeroShares() private {
        uint128 assets = 1; // after interest this is to small to convert to shares
        address borrower = makeAddr("Borrower");

        _createDebt(assets, borrower);
        vm.warp(block.timestamp + 50 * 365 days); // interest must be big, so conversion 1 asset => share be 0

        vm.expectRevert(ISilo.ZeroShares.selector);
        silo1.repay(assets, borrower);
    }

    /*
    forge test -vv --ffi --mt test_repay_tinyAmount
    */
    function test_repay_tinyAmount_1token() public {
        _repay_tinyAmount();
    }

    function _repay_tinyAmount() private {
        uint128 assets = 1;
        address borrower = makeAddr("Borrower");

        _createDebt(assets, borrower);

        _repay(assets, borrower);
    }

    /*
    forge test -vv --ffi --mt test_repay_partialWithInterest
    */
    function test_repay_partialWithInterest_1token() public {
        _repay_partialWithInterest();
    }

    function _repay_partialWithInterest() private {
        uint128 assets = 10;
        address borrower = makeAddr("Borrower");

        _createDebt(assets, borrower);
        vm.warp(block.timestamp + 1 days);

        _repay(assets, borrower);
    }

    /*
    forge test -vv --ffi --mt test_repay_tooMuch
    */
    function test_repay_tooMuch_1token() public {
        _repay_tooMuch();
    }

    function _repay_tooMuch() private {
        uint128 assets = 1e18;
        uint256 assetsToRepay = assets * 2;
        address borrower = address(this);

        _createDebt(assets, borrower);
        _mintTokens(token1, assetsToRepay, borrower);

        vm.warp(block.timestamp + 1 days);

        token1.approve(address(silo1), assetsToRepay);
        // for some reason we not bale to check for this error: Error != expected error: NH{q != Arithmetic over/underflow
        vm.expectRevert();
        silo1.repay(assetsToRepay, borrower);
    }

    /*
    forge test -vv --ffi --mt test_repayShares_fullNoInterest_noDust
    */
    function test_repayShares_fullNoInterest_noDust_1token() public {
        _repayShares_fullNoInterest_noDust();
    }

    function _repayShares_fullNoInterest_noDust() public {
        uint128 assets = 1e18;
        address borrower = makeAddr("Borrower");

        uint256 shares = _createDebt(assets, borrower);

        uint256 assetsToRepay = silo1.previewRepayShares(shares);
        assertEq(assetsToRepay, assets, "previewRepay == assets == allowance => when no interest");

        _repayShares(assets, shares, borrower);

        (,, address debtShareToken) = siloConfig.getShareTokens(address(silo1));
        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 0, "debt fully repayed");

        assertEq(token1.allowance(borrower, address(silo1)), 0, "NO allowance dust");
    }

    /*
    forge test -vv --ffi --mt test_repayShares_fullWithInterest_noDust
    */
    function test_repayShares_fullWithInterest_noDust_1token() public {
        _repayShares_fullWithInterest_noDust();
    }

    function _repayShares_fullWithInterest_noDust() private {
        uint128 assets = 1e18;
        address borrower = makeAddr("Borrower");

        uint256 shares = _createDebt(assets, borrower);
        vm.warp(block.timestamp + 1 days);

        uint256 interest = 11684166722553653; // interest less when more collateral
        uint256 assetsToRepay = silo1.previewRepayShares(shares);
        assertEq(assetsToRepay, 1e18 + interest, "assets with interest");

        _repayShares(assetsToRepay, shares, borrower);

        (,, address debtShareToken) = siloConfig.getShareTokens(address(silo1));
        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 0, "debt fully repayed");

        assertEq(token1.allowance(borrower, address(silo1)), 0, "NO allowance dust");
    }

    /*
    forge test -vv --ffi --mt test_repayShares_insufficientAllowance
    */
    function test_repayShares_insufficientAllowance_1token() public {
        _repayShares_insufficientAllowance();
    }

    function _repayShares_insufficientAllowance() private {
        uint128 assets = 1e18;
        address borrower = makeAddr("Borrower");

        uint256 shares = _createDebt(assets, borrower);
        vm.warp(block.timestamp + 1 days);

        uint256 previewRepay = silo1.previewRepayShares(shares);

        // after previewRepayShares we move time, so we will not be able to repay all
        vm.warp(block.timestamp + 1 days);

        uint256 currentPreview = silo1.previewRepayShares(shares);

        _repayShares(
            previewRepay, // this is our approval, it is less than `shares`
            shares, // this is what we want to repay
            borrower,
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, silo1, previewRepay, currentPreview
            )
        );
    }

    /*
    forge test -vv --ffi --mt test_repayShares_notFullWithInterest_withDust
    */
    function test_repayShares_notFullWithInterest_withDust_1token() public {
        _repayShares_notFullWithInterest_withDust();
    }

    /*
    forge test -vv --ffi --mt test_repay_overflowInterest
    */
    function test_repay_overflowInterest() public {
        address borrower = makeAddr("borrower");

        uint256 shares1 = _depositForBorrow(type(uint256).max / 4, makeAddr("user1"));
        uint256 shares2 = _depositForBorrow(1, makeAddr("user2"));
        uint256 shares3 = _depositForBorrow(1e18, makeAddr("user3"));

        uint256 shares4 = _depositCollateral(type(uint256).max / 4, borrower, TWO_ASSETS);
        uint256 debtShares = _borrow(type(uint256).max / 6, borrower, TWO_ASSETS);

        emit log_named_decimal_uint("LTV before", siloLens.getLtv(silo1, borrower), 16);
        _printUtilization(silo1);

        vm.warp(block.timestamp + 100000 days);
        silo1.accrueInterest();

        emit log_named_decimal_uint("LTV after", siloLens.getLtv(silo0, borrower), 16);
        _printUtilization(silo1);

        // looks like we can overflow on IRM even when we have overflow detection
        _repayShares(type(uint256).max, debtShares, borrower);

        uint256 withdraw1 = _withdraw(makeAddr("user1"), shares1);
        emit log_named_uint("deposit1", type(uint256).max / 4);
        emit log_named_uint("withdraw1", withdraw1);

        uint256 withdraw2 = _withdraw(makeAddr("user2"), shares2);
        emit log_named_uint("deposit2", 1);
        emit log_named_uint("withdraw2", withdraw2);

        uint256 withdraw3 = _withdraw(makeAddr("user3"), shares3);
        emit log_named_uint("deposit3", 1e18);
        emit log_named_uint("withdraw3", withdraw3);
    }

    function _repayShares_notFullWithInterest_withDust() private {
        uint128 assets = 1e18;
        address borrower = makeAddr("Borrower");

        uint256 shares = _createDebt(assets, borrower);
        vm.warp(block.timestamp + 1 days);

        uint256 interest = 11684166722553653; // interest less when more collateral
        uint256 previewRepay = silo1.previewRepayShares(shares);

        // after previewRepayShares we move time, so we will not be able to repay all
        vm.warp(block.timestamp + 1 days);

        _repayShares(previewRepay + interest * 3, shares, borrower);

        (,, address debtShareToken) = siloConfig.getShareTokens(address(silo1));
        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 0, "debt fully repayed");

        // 5697763189689604 is just copy/paste, IRM model QA should test if interest are correct
        uint256 dust = 5697763189689604;
        assertEq(token1.allowance(borrower, address(silo1)), dust, "allowance dust");
    }

    /*
    forge test -vv --ffi --mt test_repay_twice
    */
    function test_repay_twice_1token() public {
        _repay_twice();
    }

    function _repay_twice() private {
        uint128 assets = 1e18;
        address borrower = makeAddr("Borrower");

        _createDebt(assets, borrower);

        vm.warp(block.timestamp + 1 days);
        _repay(assets / 2, borrower);

        vm.warp(block.timestamp + 1 days);
        _repay(assets / 2, borrower);

        (,, address debtShareToken) = siloConfig.getShareTokens(address(silo1));
        uint256 interestLeft = 12011339784578816; // interest smaller for one token
        assertEq(IShareToken(debtShareToken).balanceOf(borrower), interestLeft, "interest left");
    }

    function _withdraw(address _user, uint256 _shares) private returns (uint256 assets) {
        vm.prank(_user);
        assets = silo1.redeem(_shares, _user, _user);
    }

    function _printUtilization(ISilo _silo) private {
        ISilo.UtilizationData memory data = _silo.utilizationData();

        emit log_named_decimal_uint("[UtilizationData] collateralAssets", data.collateralAssets, 18);
        emit log_named_decimal_uint("[UtilizationData] debtAssets", data.debtAssets, 18);
        emit log_named_uint("[UtilizationData] interestRateTimestamp", data.interestRateTimestamp);
    }
}
