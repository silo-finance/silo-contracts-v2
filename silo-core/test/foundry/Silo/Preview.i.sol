// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {MintableToken} from "../_common/MintableToken.sol";
import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc BorrowTest --ffi
*/
contract PreviewTest is SiloLittleHelper, Test {
    ISiloConfig siloConfig;

    function setUp() public {
        siloConfig = _setUpLocalFixture();
    }

    /*
    forge test -vv --ffi --mt test_previewDeposit_beforeInterest
    */
    function test_previewDeposit_beforeInterest() public {
        uint256 assets = 1e18;
        address depositor = makeAddr("Depositor");

        uint256 previewShares = silo0.previewDeposit(assets);
        uint256 shares = _deposit(assets, depositor);
        assertEq(previewShares, shares, "previewDeposit");
    }

    /*
    forge test -vv --ffi --mt test_previewDeposit_afterNoInterest
    */
    function test_previewDeposit_afterNoInterest() public {
        uint256 assets = 1e18;
        address depositor = makeAddr("Depositor");

        uint256 sharesBefore = _deposit(assets, depositor);

        vm.warp(block.timestamp + 365 days);
        silo0.accrueInterest();

        uint256 previewShares = silo0.previewDeposit(assets);
        assertEq(previewShares, _deposit(assets, depositor), "previewDeposit");
        assertEq(previewShares, sharesBefore, "without interest shares are the same");
    }

    /*
    forge test -vv --ffi --mt test_previewDeposit_withInterest
    */
    function test_previewDeposit_withInterest() public {
        uint256 assets = 1e18;
        address depositor = makeAddr("Depositor");
        address borrower = makeAddr("Borrower");

        uint256 sharesBefore = _deposit(assets, depositor);
        _depositForBorrow(assets, depositor);

        _deposit(assets, borrower);
        _borrow(assets / 10, borrower);

        vm.warp(block.timestamp + 365 days);

        uint256 previewShares0 = silo0.previewDeposit(assets);
        uint256 previewShares1 = silo1.previewDeposit(assets);

        assertLt(previewShares1, previewShares0, "you get less shares on silo1 because we have interests here");
        assertEq(previewShares1, _depositForBorrow(assets, depositor), "previewDeposit with interest on the fly");

        silo0.accrueInterest();
        silo1.accrueInterest();

        assertEq(sharesBefore, silo0.previewDeposit(assets), "no interest in silo0, so preview should be the same");

        previewShares1 = silo1.previewDeposit(assets);
        assertEq(previewShares1, 998943732462302604, "with interests, we will receive less shares than assets amount");
        assertEq(previewShares1, _depositForBorrow(assets, depositor), "previewDeposit after accrueInterest()");
    }

    /*
    forge test -vv --ffi --mt test_previewBorrow_zero
    */
    function test_previewBorrow_zero() public {
        uint256 assets = 1e18;
        assertEq(1e18, silo0.previewBorrow(assets));
    }

    /*
    forge test -vv --ffi --mt test_previewBorrow_beforeInterest
    */
    function test_previewBorrow_beforeInterest() public {
        uint256 assets = 1e18;
        uint256 assetsToBorrow = 1e17;
        address borrower = makeAddr("Borrower");
        address somebody = makeAddr("Somebody");

        _deposit(assets, borrower);

        // deposit to both silos
        _deposit(assets, somebody);
        _depositForBorrow(assets, somebody);

        uint256 previewBorrowShares = silo1.previewBorrow(assetsToBorrow);
        assertEq(previewBorrowShares, assetsToBorrow, "previewBorrow shares");
        assertEq(previewBorrowShares, _borrow(assetsToBorrow, borrower), "previewBorrow");
    }

    /*
    forge test -vv --ffi --mt test_previewBorrow_withInterest
    */
    function test_previewBorrow_withInterest() public {
        uint256 assets = 1e18;
        uint256 assetsToBorrow = 1e17;
        address borrower = makeAddr("Borrower");
        address somebody = makeAddr("Somebody");

        _deposit(assets, borrower);

        // deposit to both silos
        _deposit(assets, somebody);
        _depositForBorrow(assets, somebody);

        uint256 sharesBefore = _borrow(assetsToBorrow, borrower);

        vm.warp(block.timestamp + 365 days);

        uint256 previewBorrowShares = silo1.previewBorrow(assetsToBorrow);
        assertEq(previewBorrowShares, 98609754428689114, "previewBorrow shares");
        assertEq(previewBorrowShares, _borrow(assetsToBorrow, borrower), "previewBorrow after accrueInterest");
        assertLt(sharesBefore + previewBorrowShares, assetsToBorrow * 2, "we should have less shares then amount of assets+interest");
    }

    /*
    forge test -vv --ffi --mt test_previewRepay_noInterestNoDebt
    */
    function test_previewRepay_noInterestNoDebt() public {
        uint256 assets = 1e18;
        address borrower = makeAddr("Borrower");

        uint256 sharesToRepay = silo1.previewRepay(assets);

        _createDebt(assets, borrower);

        assertEq(sharesToRepay, assets, "previewRepay == assets == shares");

        uint256 returnedAssets = _repayShares(assets, sharesToRepay, borrower);
        assertEq(returnedAssets, assets, "preview should give us exact assets");
    }

    /*
    forge test -vv --ffi --mt test_previewRepay_noInterest
    */
    function test_previewRepay_noInterest() public {
        uint256 assets = 1e18;
        address borrower = makeAddr("Borrower");

        _createDebt(assets, borrower);

        uint256 sharesToRepay = silo1.previewRepay(assets);
        assertEq(sharesToRepay, assets, "previewRepay == assets == shares");

        uint256 returnedAssets = _repayShares(assets, sharesToRepay, borrower);
        assertEq(returnedAssets, assets, "preview should give us exact assets");
    }

    /*
    forge test -vv --ffi --mt test_previewRepay_withInterest
    */
    function test_previewRepay_withInterest() public {
        uint256 assets = 1e18;
        address borrower = makeAddr("Borrower");

        _createDebt(assets, borrower);
        vm.warp(block.timestamp + 1 days);

        uint256 sharesToRepay = silo1.previewRepay(assets);
        assertLt(sharesToRepay, assets, "when assets includes interst, shares amount will be lower");

        uint256 returnedAssets = _repayShares(assets, sharesToRepay, borrower);
        assertEq(returnedAssets, assets, "preview should give us exact assets");
    }
}
