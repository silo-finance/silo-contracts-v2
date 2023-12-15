// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {SiloFixture} from "../../_common/fixtures/SiloFixture.sol";
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
        vm.expectRevert("ERC20: insufficient allowance");
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
    function test_repay_throwZeroShares() public {
        uint128 assets = 1; // after interest this is to small to convert to shares
        address borrower = makeAddr("Borrower");

        _createDebt(assets, borrower);
        vm.warp(block.timestamp + 365 days);

        vm.expectRevert(ISilo.ZeroShares.selector);
        silo1.repay(assets, borrower);
    }

    /*
    forge test -vv --ffi --mt test_repay_tinyAmount
    */
    function test_repay_tinyAmount() public {
        uint128 assets = 1;
        address borrower = makeAddr("Borrower");

        _createDebt(assets, borrower);

        _repay(assets, borrower);
    }

    /*
    forge test -vv --ffi --mt test_repay_partialWithInterest
    */
    function test_repay_partialWithInterest() public {
        uint128 assets = 10;
        address borrower = makeAddr("Borrower");

        _createDebt(assets, borrower);
        vm.warp(block.timestamp + 1 days);

        _repay(assets, borrower);
    }

    /*
    forge test -vv --ffi --mt test_repay_tooMuch
    */
    function test_repay_tooMuch() public {
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
    function test_repayShares_fullNoInterest_noDust() public {
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
    function test_repayShares_fullWithInterest_noDust() public {
        uint128 assets = 1e18;
        address borrower = makeAddr("Borrower");

        uint256 shares = _createDebt(assets, borrower);
        vm.warp(block.timestamp + 1 days);

        uint256 interest = 11684166722553653;
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
    function test_repayShares_insufficientAllowance() public {
        uint128 assets = 1e18;
        address borrower = makeAddr("Borrower");

        uint256 shares = _createDebt(assets, borrower);
        vm.warp(block.timestamp + 1 days);

        uint256 previewRepay = silo1.previewRepayShares(shares);

        // after previewRepayShares we move time, so we will not be able to repay all
        vm.warp(block.timestamp + 1 days);

        _repayShares(previewRepay, shares, borrower, "ERC20: insufficient allowance");
    }

    /*
    forge test -vv --ffi --mt test_repayShares_notFullWithInterest_withDust
    */
    function test_repayShares_notFullWithInterest_withDust() public {
        uint128 assets = 1e18;
        address borrower = makeAddr("Borrower");

        uint256 shares = _createDebt(assets, borrower);
        vm.warp(block.timestamp + 1 days);

        uint256 interest = 11684166722553653;
        uint256 previewRepay = silo1.previewRepayShares(shares);

        // after previewRepayShares we move time, so we will not be able to repay all
        vm.warp(block.timestamp + 1 days);

        _repayShares(previewRepay + interest * 3, shares, borrower);

        (,, address debtShareToken) = siloConfig.getShareTokens(address(silo1));
        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 0, "debt fully repayed");

        // 5697763189689604 is just copy/paste, IRM model QA should test if interest are correct
        assertEq(token1.allowance(borrower, address(silo1)), 5697763189689604, "allowance dust");
    }

    /*
    forge test -vv --ffi --mt test_repay_twice
    */
    function test_repay_twice() public {
        uint128 assets = 1e18;
        address borrower = makeAddr("Borrower");

        _createDebt(assets, borrower);

        vm.warp(block.timestamp + 1 days);
        _repay(assets / 2, borrower);

        vm.warp(block.timestamp + 1 days);
        _repay(assets / 2, borrower);

        (,, address debtShareToken) = siloConfig.getShareTokens(address(silo1));
        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 12011339784578816, "interest left");

    }
}
