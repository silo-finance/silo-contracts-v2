// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {MintableToken} from "../_common/MintableToken.sol";
import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc PreviewTest
*/
contract PreviewTest is SiloLittleHelper, Test {
    uint256 constant DEPOSIT_BEFORE = 1e18 + 9876543211;

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
    forge test -vv --ffi --mt test_previewDeposit_beforeInterest
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_previewDeposit_beforeInterest_fuzz(uint256 _assets) public {
        vm.assume(_assets > 0);

        uint256 previewShares = silo0.previewDeposit(_assets);
        uint256 shares = _deposit(_assets, depositor);
        assertEq(previewShares, shares, "previewDeposit");
    }

    /*
    forge test -vv --ffi --mt test_previewMint_beforeInterest
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_previewMint_beforeInterest_fuzz(uint256 _shares) public {
        vm.assume(_shares > 0);

        _assertPreviewMint(_shares);
    }

    /*
    forge test -vv --ffi --mt test_previewDeposit_afterNoInterest
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_previewDeposit_afterNoInterest_fuzz(uint256 _assets) public {
        vm.assume(_assets > 0);
        vm.assume(_assets < type(uint128).max);

        uint256 sharesBefore = _deposit(_assets, depositor);

        vm.warp(block.timestamp + 365 days);
        silo0.accrueInterest();

        uint256 previewShares = silo0.previewDeposit(_assets);
        assertEq(previewShares, _deposit(_assets, depositor), "previewDeposit");
        assertEq(previewShares, sharesBefore, "without interest shares are the same");
    }

    /*
    forge test -vv --ffi --mt test_previewMint_afterNoInterest
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_previewMint_afterNoInterest_fuzz(uint256 _depositAmount, uint256 _shares) public {
        vm.assume(_depositAmount < type(uint128).max);
        vm.assume(_depositAmount > 0);
        vm.assume(_shares < type(uint128).max);
        vm.assume(_shares > 0);

        // deposit something
        _deposit(_depositAmount, makeAddr("any"));

        vm.warp(block.timestamp + 365 days);
        silo0.accrueInterest();

        _assertPreviewMint(_shares);
    }

    /*
    forge test -vv --ffi --mt test_previewDeposit_withInterest
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_previewDeposit_withInterest_fuzz(uint256 _assets) public {
        vm.assume(_assets < type(uint128).max);
        vm.assume(_assets > 0);

        uint256 sharesBefore = _deposit(_assets, depositor);
        _depositForBorrow(_assets, depositor);

        _deposit(_assets / 10 == 0 ? 2 : _assets, borrower);
        _borrow(_assets / 10 + 1, borrower); // +1 ensure we not borrowing 0

        vm.warp(block.timestamp + 365 days);

        uint256 previewShares0 = silo0.previewDeposit(_assets);
        uint256 previewShares1 = silo1.previewDeposit(_assets);

        assertLe(previewShares1, previewShares0, "you can get less shares on silo1 because we have interests here");
        assertEq(previewShares1, _depositForBorrow(_assets, depositor), "previewDeposit with interest on the fly");

        silo0.accrueInterest();
        silo1.accrueInterest();

        assertEq(sharesBefore, silo0.previewDeposit(_assets), "no interest in silo0, so preview should be the same");

        previewShares1 = silo1.previewDeposit(_assets);
        assertLe(previewShares1, _assets, "with interests, we can receive less shares than assets amount");
        assertEq(previewShares1, _depositForBorrow(_assets, depositor), "previewDeposit after accrueInterest()");
    }

    /*
    forge test -vv --ffi --mt test_previewMint_withInterest
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_previewMint_withInterest_fuzz(uint256 _shares) public {
        vm.assume(_shares < type(uint128).max);
        vm.assume(_shares > 0);

        _createInterest();

        _assertPreviewMint(_shares);
    }

    /*
    forge test -vv --ffi --mt test_previewBorrow_zero
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_previewBorrow_zero_fuzz(uint256 _assets) public {
        assertEq(_assets, silo0.previewBorrow(_assets));
    }

    /*
    forge test -vv --ffi --mt test_previewBorrow_beforeInterest
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_previewBorrow_beforeInterest_fuzz(uint256 _assets) public {
        vm.assume(_assets < type(uint128).max);
        vm.assume(_assets > 0);

        uint256 assetsToBorrow = _assets / 10;

        if (assetsToBorrow == 0) {
            _assets = 3;
            assetsToBorrow = 1;
        }

        address somebody = makeAddr("Somebody");

        _deposit(_assets, borrower);

        // deposit to both silos
        _deposit(_assets, somebody);
        _depositForBorrow(_assets, somebody);

        uint256 previewBorrowShares = silo1.previewBorrow(assetsToBorrow);
        assertEq(previewBorrowShares, assetsToBorrow, "previewBorrow shares");
        assertEq(previewBorrowShares, _borrow(assetsToBorrow, borrower), "previewBorrow");
    }

    /*
    forge test -vv --ffi --mt test_previewBorrow_withInterest
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_previewBorrow_withInterest_fuzz(uint256 _assets) public {
        vm.assume(_assets < type(uint128).max);
        vm.assume(_assets > 0);

        uint256 assetsToBorrow = _assets / 10;

        if (assetsToBorrow == 0) {
            _assets = 3;
            assetsToBorrow = 1;
        }

        address somebody = makeAddr("Somebody");

        _deposit(_assets, borrower);

        // deposit to both silos
        _deposit(_assets, somebody);
        _depositForBorrow(_assets, somebody);

        uint256 sharesBefore = _borrow(assetsToBorrow, borrower);

        vm.warp(block.timestamp + 365 days);

        uint256 previewBorrowShares = silo1.previewBorrow(assetsToBorrow);
        assertEq(previewBorrowShares, _borrow(assetsToBorrow, borrower), "previewBorrow after accrueInterest");
        assertLe(previewBorrowShares, sharesBefore, "shares before interest can not be higher for same borrow amount");
    }

    /*
    forge test -vv --ffi --mt test_previewRepay_noInterestNoDebt
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_previewRepay_noInterestNoDebt_fuzz(uint256 _assets) public {
        vm.assume(_assets < type(uint128).max);
        vm.assume(_assets > 10);

        uint256 sharesToRepay = silo1.previewRepay(_assets);

        _createDebt(_assets, borrower);

        assertEq(sharesToRepay, _assets, "previewRepay == assets == shares");

        uint256 returnedAssets = _repayShares(_assets, sharesToRepay, borrower);
        assertEq(returnedAssets, _assets, "preview should give us exact assets");
    }

    /*
    forge test -vv --ffi --mt test_previewRepay_noInterest
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_previewRepay_noInterest_fuzz(uint256 _assets) public {
        vm.assume(_assets < type(uint128).max);
        vm.assume(_assets > 10);

        _createDebt(_assets, borrower);

        uint256 sharesToRepay = silo1.previewRepay(_assets);
        assertEq(sharesToRepay, _assets, "previewRepay == assets == shares");

        uint256 returnedAssets = _repayShares(_assets, sharesToRepay, borrower);
        assertEq(returnedAssets, _assets, "preview should give us exact assets");
    }

    /*
    forge test -vv --ffi --mt test_previewRepay_withInterest
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_previewRepay_withInterest_fuzz(uint256 _assets) public {
        vm.assume(_assets < type(uint128).max);
        vm.assume(_assets > 10);

        _createDebt(_assets, borrower);
        vm.warp(block.timestamp + 1 days);

        uint256 sharesToRepay = silo1.previewRepay(_assets);
        assertLe(sharesToRepay, _assets, "when assets includes interest, shares amount can be lower");

        uint256 returnedAssets = _repayShares(_assets, sharesToRepay, borrower);
        assertEq(returnedAssets, _assets, "preview should give us exact assets");
    }

    function _createInterest() internal {
        uint256 assets = 1e18 + 123456789;

        _deposit(assets, depositor);
        _depositForBorrow(assets, depositor);

        _deposit(assets, borrower);
        _borrow(assets / 10, borrower);

        vm.warp(block.timestamp + 365 days);

        silo0.accrueInterest();
        silo1.accrueInterest();
    }

    function _assertPreviewMint(uint256 _shares) internal {
        // uint256 shares = 1e18 + 987654211;
        uint256 previewMint = silo0.previewMint(_shares);

        token0.mint(depositor, previewMint);

        vm.startPrank(depositor);
        token0.approve(address(silo0), previewMint);
        uint256 depositedAssets = silo0.mint(_shares, depositor);

        assertEq(depositedAssets, previewMint, "previewMint == depositedAssets");
    }
}
