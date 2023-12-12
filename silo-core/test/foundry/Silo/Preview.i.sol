// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

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
        siloConfig = _setUpLocalFixture(SiloConfigsNames.LOCAL_NO_ORACLE_NO_LTV_SILO);
    }

    /*
    forge test -vv --ffi --mt test_previewDepositType_beforeInterest_fuzz2
    */
    /// forge-config: core.fuzz.runs = 50000
    function test_previewDeposit_beforeInterest_fuzz(uint256 _assets, bool _defaultType, uint8 _type) public {
        _previewDeposit_beforeInterest(_assets, _defaultType, _type);
    }

    /*
    forge test -vv --ffi --mt test_previewDeposit_afterNoInterest
    */
    /// forge-config: core.fuzz.runs = 50000
    function test_previewDeposit_afterNoInterest_fuzz(uint128 _assets, bool _defaultType) public {
        _previewDeposit_afterNoInterest_(_assets, _defaultType, uint8(ISilo.AssetType.Collateral));
    }

    /*
    forge test -vv --ffi --mt test_previewDeposit_withInterest
    */
    /// forge-config: core.fuzz.runs = 50000
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

        assertLe(
            previewShares1,
            previewShares0,
            "you can get less shares on silo1 than on silo0, because we have interests here"
        );

        assertEq(
            previewShares1,
            _depositForBorrow(_assets, depositor),
            "previewDeposit with interest on the fly - must be as close but NOT more"
        );

        silo0.accrueInterest();
        silo1.accrueInterest();

        assertEq(silo0.previewDeposit(_assets), sharesBefore, "no interest in silo0, so preview should be the same");

        previewShares1 = silo1.previewDeposit(_assets);

        assertLe(previewShares1, _assets, "with interests, we can receive less shares than assets amount");

        assertEq(
            previewShares1,
            _depositForBorrow(_assets, depositor),
            "previewDeposit after accrueInterest() - as close, but NOT more"
        );
    }

    /*
    forge test -vv --ffi --mt test_previewMint_beforeInterest
    */
    /// forge-config: core.fuzz.runs = 50000
    function test_previewMint_beforeInterest_fuzz(uint256 _shares, bool _defaultType, uint8 _type) public {
        vm.assume(_shares > 0);

        _assertPreviewMint(_shares, _defaultType, _type);
    }

    /*
    forge test -vv --ffi --mt test_previewMint_afterNoInterest_fuzz
    */
    /// forge-config: core.fuzz.runs = 50000
    function test_previewMint_afterNoInterest_fuzz(
        uint128 _depositAmount,
        uint128 _shares,
        bool _defaultType,
        uint8 _type
    ) public {
        _previewMint_afterNoInterest(_depositAmount, _shares, _defaultType, _type);
        _assertPreviewMint(_shares, _defaultType, _type);
    }

    /*
    forge test -vv --ffi --mt test_previewMint_withInterest_fuzz
    */
    /// forge-config: core.fuzz.runs = 50000
    function test_previewMint_withInterest_fuzz(uint128 _shares, bool _defaultType, uint8 _type) public {
        vm.assume(_shares > 0);

        _createInterest();

        _assertPreviewMint(_shares, _defaultType, _type);
    }

    /*
    forge test -vv --ffi --mt test_previewBorrow_zero_fuzz
    */
    /// forge-config: core.fuzz.runs = 50000
    function test_previewBorrow_zero_fuzz(uint256 _assets) public {
        assertEq(silo0.previewBorrow(_assets), _assets);
    }

    /*
    forge test -vv --ffi --mt test_previewBorrow_beforeInterest_fuzz
    */
    /// forge-config: core.fuzz.runs = 50000
    function test_previewBorrow_beforeInterest_fuzz(uint128 _assets) public {
        vm.assume(_assets > 0);

        uint256 assetsToBorrow = _assets / 10;

        // can be 0 if _assets < 10
        if (assetsToBorrow == 0) {
            _assets = 3;
            assetsToBorrow = 1;
        }

        _createBorrowCase(_assets);

        uint256 previewBorrowShares = silo1.previewBorrow(assetsToBorrow);

        assertEq(previewBorrowShares, assetsToBorrow, "previewBorrow shares are exact as amount when no interest");
        assertEq(previewBorrowShares, _borrow(assetsToBorrow, borrower), "previewBorrow - expect exact match");
    }

    /*
    forge test -vv --ffi --mt test_previewBorrow_withInterest
    */
    /// forge-config: core.fuzz.runs = 50000
    function test_previewBorrow_withInterest_fuzz(uint128 _assets) public {
        vm.assume(_assets > 0);

        uint256 assetsToBorrow = _assets / 10;

        if (assetsToBorrow == 0) {
            _assets = 3;
            assetsToBorrow = 1;
        }

        _createBorrowCase(_assets);

        uint256 sharesBefore = _borrow(assetsToBorrow, borrower);

        vm.warp(block.timestamp + 365 days);

        uint256 previewBorrowShares = silo1.previewBorrow(assetsToBorrow);

        assertGe(
            sharesBefore,
            previewBorrowShares,
            "shares before interest will always be eq or more, than result with interest, because with interest there is higher total"
        );

        assertEq(previewBorrowShares, _borrow(assetsToBorrow, borrower), "previewBorrow after accrueInterest");
    }

    /*
    forge test -vv --ffi --mt test_previewRepay_noInterestNoDebt_fuzz
    */
    /// forge-config: core.fuzz.runs = 50000
    function test_previewRepay_noInterestNoDebt_fuzz(uint128 _assets, bool _useShares, bool _repayFull) public {
        _previewRepay_noInterestNoDebt(_assets, _useShares, _repayFull);
    }

    /*
    forge test -vv --ffi --mt test_previewRepayShares_noInterest_fuzz
    */
    /// forge-config: core.fuzz.runs = 50000
    function test_previewRepay_noInterest_fuzz(uint128 _assets, bool _useShares, bool _repayFull) public {
        _previewRepay_noInterest(_assets, _useShares, _repayFull);
    }

    /*
    forge test -vv --ffi --mt test_previewRepay_withInterest_fuzz
    */
    /// forge-config: core.fuzz.runs = 50000
    function test_previewRepay_withInterest_fuzz(uint128 _assets, bool _useShares, bool _repayFull) public {
        _previewRepay_withInterest(_assets, _useShares, _repayFull);
    }

    /*
    forge test -vv --ffi --mt test_previewWithdraw_noInterestNoDebt_fuzz
    */
    /// forge-config: core.fuzz.runs = 50000
    function test_previewWithdraw_noInterestNoDebt_fuzz(uint128 _assets, bool _doRedeem, bool _partial) public {
        _previewWithdraw_noInterestNoDebt(_assets, _doRedeem, _partial);
    }

    /*
    forge test -vv --ffi --mt test_previewWithdraw_noDebt_fuzz
    */
    /// forge-config: core.fuzz.runs = 50000
    function test_previewWithdraw_noDebt_fuzz(uint128 _assets, bool _doRedeem, bool _partial) public {
        _previewWithdraw_depositNoInterest(_assets, _doRedeem, _partial);
    }

    /*
    forge test -vv --ffi --mt test_previewWithdraw_debt_fuzz
    */
    /// forge-config: core.fuzz.runs = 50000
    function test_previewWithdraw_debt_fuzz(uint128 _assets, bool _doRedeem, bool _interest, bool _partial) public {
        _previewWithdraw_debt(_assets, _doRedeem, _interest, _partial);
    }

    function _previewWithdraw_noInterestNoDebt(uint128 _assetsOrShares, bool _doRedeem, bool _partial) internal {
        uint128 amountToUse = _partial ? uint128(uint256(_assetsOrShares) * 37 / 100) : _assetsOrShares;
        vm.assume(amountToUse > 0);

        // preview before deposit creation
        uint256 preview = _doRedeem ? silo0.previewRedeem(amountToUse) : silo0.previewWithdraw(amountToUse);

        _deposit(_assetsOrShares, depositor);

        assertEq(preview, amountToUse, "previewWithdraw == assets == shares, when no interest");

        _assertPreviewWithdraw(preview, amountToUse, _doRedeem);
    }

    function _previewWithdraw_depositNoInterest(uint128 _assetsOrShares, bool _doRedeem, bool _partial) internal {
        uint128 amountToUse = _partial ? uint128(uint256(_assetsOrShares) * 37 / 100) : _assetsOrShares;
        vm.assume(amountToUse > 0);

        _deposit(uint256(_assetsOrShares) * 2 - (_assetsOrShares % 2), depositor);

        uint256 preview = _doRedeem ? silo0.previewRedeem(amountToUse) : silo0.previewWithdraw(amountToUse);

        assertEq(preview, amountToUse, "previewWithdraw == assets == shares, when no interest");

        _assertPreviewWithdraw(preview, amountToUse, _doRedeem);
    }

    function _previewWithdraw_debt(uint128 _assetsOrShares, bool _doRedeem, bool _interest, bool _partial) internal {
        uint128 amountToUse = _partial ? uint128(uint256(_assetsOrShares) * 37 / 100) : _assetsOrShares;
        vm.assume(amountToUse > 0);

        // we need interest on silo0, where we doing deposit
        _depositForBorrow(uint256(_assetsOrShares) * 2, borrower);
        _deposit(uint256(_assetsOrShares) * 2 + (_assetsOrShares % 2), depositor);

        vm.prank(borrower);
        silo0.borrow(_assetsOrShares / 2 == 0 ? 1 : _assetsOrShares / 2, borrower, borrower);

        if (_interest) vm.warp(block.timestamp + 100 days);

        uint256 preview = _doRedeem ? silo0.previewRedeem(amountToUse) : silo0.previewWithdraw(amountToUse);

        if (!_interest) assertEq(preview, amountToUse, "previewWithdraw == assets == shares, when no interest");

        _assertPreviewWithdraw(preview, amountToUse, _doRedeem);
    }

    function _previewRepay_noInterestNoDebt(uint128 _assetsOrShares, bool _useShares, bool _repayFull) internal {
        uint128 amountToUse = _repayFull ? _assetsOrShares : uint128(uint256(_assetsOrShares) * 37 / 100);
        vm.assume(amountToUse > 0);

        // preview before debt creation
        uint256 preview = _useShares ? silo1.previewRepayShares(amountToUse) : silo1.previewRepay(amountToUse);

        _createDebt(_assetsOrShares, borrower);

        assertEq(preview, amountToUse, "previewRepay == assets == shares, when no interest");

        _assertPreviewRepay(preview, amountToUse, _useShares);
    }

    function _previewRepay_noInterest(uint128 _assetsOrShares, bool _useShares, bool _repayFull) internal {
        uint128 amountToUse = _repayFull ? _assetsOrShares : uint128(uint256(_assetsOrShares) * 37 / 100);
        vm.assume(amountToUse > 0);

        _createDebt(_assetsOrShares, borrower);

        uint256 preview = _useShares ? silo1.previewRepayShares(amountToUse) : silo1.previewRepay(amountToUse);

        assertEq(preview, amountToUse, "previewRepay == assets == shares, when no interest");

        _assertPreviewRepay(preview, amountToUse, _useShares);
    }

    function _previewRepay_withInterest(uint128 _assetsOrShares, bool _useShares, bool _repayFull) internal {
        uint128 amountToUse = _repayFull ? _assetsOrShares : uint128(uint256(_assetsOrShares) * 37 / 100);
        vm.assume(amountToUse > 0);

        _createDebt(_assetsOrShares, borrower);
        vm.warp(block.timestamp + 100 days);

        uint256 preview = _useShares ? silo1.previewRepayShares(amountToUse) : silo1.previewRepay(amountToUse);

        _assertPreviewRepay(preview, amountToUse, _useShares);
    }

    function _assertPreviewRepay(uint256 _preview, uint128 _assetsOrShares, bool _useShares) internal {
        vm.assume(_preview > 0);

        uint256 repayResult = _useShares
            ? _repayShares(type(uint256).max, _assetsOrShares, borrower)
            : _repay(_assetsOrShares, borrower);

        assertGt(repayResult, 0, "expect any repay amount > 0");

        assertEq(_preview, repayResult, "preview should give us exact repay result");
    }

    function _assertPreviewWithdraw(uint256 _preview, uint128 _assetsOrShares, bool _useRedeem) internal {
        vm.assume(_preview > 0);
        vm.prank(depositor);

        uint256 results = _useRedeem
            ? silo0.redeem(_assetsOrShares, depositor, depositor)
            : silo0.withdraw(_assetsOrShares, depositor, depositor);

        assertGt(results, 0, "expect any withdraw amount > 0");

        if (_useRedeem) assertEq(_preview, results, "preview should give us exact result, NOT more");
        else assertEq(_preview, results, "preview should give us exact result, NOT fewer");
    }

    function _createInterest() internal {
        uint256 assets = 1e18 + 123456789; // some not even number

        _deposit(assets, depositor);
        _depositForBorrow(assets, depositor);

        _deposit(assets, borrower);
        _borrow(assets / 10, borrower);

        vm.warp(block.timestamp + 365 days);

        silo0.accrueInterest();
        silo1.accrueInterest();
    }

    function _createBorrowCase(uint128 _assets) internal {
        address somebody = makeAddr("Somebody");

        _deposit(_assets, borrower);

        // deposit to both silos
        _deposit(_assets, somebody);
        _depositForBorrow(_assets, somebody);
    }

    function _previewMint_afterNoInterest(
        uint128 _depositAmount,
        uint128 _shares,
        bool _defaultType,
        uint8 _type
    ) internal {
        vm.assume(_depositAmount > 0);
        vm.assume(_shares > 0);
        vm.assume(_type == 0 || _type == 1);

        // deposit something
        _deposit(_depositAmount, makeAddr("any"));

        vm.warp(block.timestamp + 365 days);
        silo0.accrueInterest();

        _assertPreviewMint(_shares, _defaultType, _type);
    }

    function _assertPreviewMint(uint256 _shares, bool _defaultType, uint8 _type) internal {
        vm.assume(_type == 0 || _type == 1);

        uint256 previewMint = _defaultType
            ? silo0.previewMint(_shares)
            : silo0.previewMint(_shares, ISilo.AssetType(_type));

        token0.mint(depositor, previewMint);

        vm.startPrank(depositor);
        token0.approve(address(silo0), previewMint);

        uint256 depositedAssets = _defaultType
            ? silo0.mint(_shares, depositor)
            : silo0.mint(_shares, depositor, ISilo.AssetType(_type));

        assertEq(previewMint, depositedAssets, "previewMint == depositedAssets, NOT fewer");
    }

    function _previewDeposit_beforeInterest(uint256 _assets, bool _defaultType, uint8 _type) internal {
        vm.assume(_assets > 0);
        vm.assume(_type == 0 || _type == 1);

        uint256 previewShares = _defaultType
            ? silo0.previewDeposit(_assets)
            : silo0.previewDeposit(_assets, ISilo.AssetType(_type));

        uint256 shares = _defaultType
            ? _deposit(_assets, depositor)
            : _deposit(_assets, depositor, ISilo.AssetType(_type));

        assertEq(previewShares, shares, "previewDeposit must return as close but NOT more");
    }

    function _previewDeposit_afterNoInterest_(uint128 _assets, bool _defaultType, uint8 _type) internal {
        vm.assume(_assets > 0);
        vm.assume(_type == 0 || _type == 1);

        uint256 sharesBefore = _defaultType
            ? _deposit(_assets, depositor)
            : _deposit(_assets, depositor, ISilo.AssetType(_type));

        vm.warp(block.timestamp + 365 days);
        silo0.accrueInterest();

        uint256 previewShares = _defaultType
            ? silo0.previewDeposit(_assets)
            : silo0.previewDeposit(_assets, ISilo.AssetType(_type));

        uint256 gotShares = _defaultType
            ? _deposit(_assets, depositor)
            : _deposit(_assets, depositor, ISilo.AssetType(_type));

        assertEq(previewShares, gotShares, "previewDeposit must return as close but NOT more");
        assertEq(previewShares, sharesBefore, "without interest shares must be the same");
    }
}
