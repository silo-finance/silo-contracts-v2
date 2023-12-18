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
    forge test -vv --ffi --mc MaxTest
*/
contract MaxTest is SiloLittleHelper, Test {
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
    forge test -vv --ffi --mt test_maxDeposit_emptySilo
    */
    function test_maxDeposit_emptySilo() public {
        uint256 maxDeposit = silo0.maxDeposit(depositor);
        assertEq(maxDeposit, type(uint256).max, "on empty silo, MAX is just no limit");
        _deposit(maxDeposit, depositor);

        _assertWeCanNotDepositMore(silo0, depositor);
    }

    /*
    forge test -vv --ffi --mt test_maxDeposit_whenBorrow
    */
    function test_maxDeposit_whenBorrow() public {
        uint256 _initialDeposit = 1e18;

        _depositForBorrow(_initialDeposit / 3, depositor);
        _deposit(_initialDeposit / 3 * 2, borrower);
        _borrow(_initialDeposit / 3, borrower);

        assertEq(silo0.maxDeposit(borrower), type(uint256).max - (_initialDeposit / 3 * 2), "no debt - max deposit");
        assertEq(silo1.maxDeposit(borrower), 0, "can not deposit with debt");
    }

    /*
    forge test -vv --ffi --mt test_maxDeposit_withDeposit_fuzz
    */
    /// forge-config: core.fuzz.runs = 10000
    function test_maxDeposit_withDeposit_fuzz(uint256 _initialDeposit) public {
        vm.assume(_initialDeposit > 0);
        vm.assume(_initialDeposit < type(uint256).max); // max case is covered on test_maxDeposit_emptySilo

        _deposit(_initialDeposit, depositor);

        uint256 maxDeposit = silo0.maxDeposit(depositor);
        assertEq(maxDeposit, type(uint256).max - _initialDeposit, "with deposit, max is MAX - deposit");

        _deposit(maxDeposit, depositor);

        _assertWeCanNotDepositMore(silo0, depositor);
    }

    /*
    forge test -vv --ffi --mt test_maxDeposit_withInterest_fuzz
    */
    /// forge-config: core.fuzz.runs = 10000
    function test_maxDeposit_withInterest_fuzz(uint128 _initialDeposit) public {
        vm.assume(_initialDeposit > 3); // we need to be able /3

        _depositForBorrow(_initialDeposit / 3, depositor);

        _deposit(_initialDeposit / 3 * 2, borrower);
        _borrow(_initialDeposit / 3, borrower);

        vm.warp(block.timestamp + 100 days);

        uint256 maxDeposit = silo1.maxDeposit(depositor);

        emit log_named_decimal_uint("maxDeposit", maxDeposit, 18);
        emit log_named_uint("interest", type(uint256).max - (_initialDeposit / 3 * 2) - maxDeposit);

        assertLt(
            maxDeposit,
            type(uint256).max - (_initialDeposit / 3 * 2),
            "with interest we expecting less than simply sub the initial deposit"
        );

        _depositForBorrow(maxDeposit, depositor);

        //
//        _assertWeCanNotDepositMore(silo1, depositor, 10);
    }


    /*
    forge test -vv --ffi --mt test_maxDeposit_repayWithInterest_fuzz
    */
    /// forge-config: core.fuzz.runs = 10000
    function test_maxDeposit_repayWithInterest_fuzz(
//        uint128 _initialDeposit
    ) public {
        uint128 _initialDeposit = 1e18;
        uint128 toBorrow = _initialDeposit / 3;

        vm.assume(_initialDeposit > 3); // we need to be able /3

        _depositForBorrow(toBorrow, depositor);

        _deposit(_initialDeposit / 3 * 2, borrower);
        _borrow(toBorrow, borrower);

        vm.warp(block.timestamp + 10 days);

        (,, address debtShareToken) = silo1.config().getShareTokens(address(silo1));

        _repayShares(type(uint256).max, IShareToken(debtShareToken).balanceOf(borrower), borrower);
        assertGt(token1.balanceOf(address(silo1)), toBorrow, "we expect to repay with interest");
        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 0, "all debt must be repay");

        uint256 maxDeposit = silo1.maxDeposit(depositor);

        emit log_named_decimal_uint("maxDeposit", maxDeposit, 18);
        emit log_named_decimal_uint("balanceOf(silo)", token1.balanceOf(address(silo1)), 18);
        emit log_named_decimal_uint("interest (with fees)", token1.balanceOf(address(silo1)) - toBorrow, 18);
        emit log_named_decimal_uint("           diff", type(uint256).max - maxDeposit, 18);

        assertEq(
            maxDeposit,
            type(uint256).max - token1.balanceOf(address(silo1)),
            "with interest we expecting less than simply sub the initial deposit"
        );

        vm.startPrank(borrower);
        token1.transfer(depositor, token1.balanceOf(borrower));

        _depositForBorrow(maxDeposit, depositor);

        _assertWeCanNotDepositMore(silo1, depositor);
    }

    /*
    forge test -vv --ffi --mt test_maxMint_emptySilo
    */
    function test_maxMint_emptySilo() public {
        uint256 maxMint = silo0.maxMint(depositor);
        assertEq(maxMint, type(uint256).max, "on empty silo, MAX is just no limit");
        _deposit(maxMint, depositor);

        _assertWeCanNotDepositMore(silo0, depositor);
    }

    /*
    forge test -vv --ffi --mt test_maxMint_afterNoInterest_fuzz
    */
    /// forge-config: core.fuzz.runs = 10000
    function test_maxMint_afterNoInterest_fuzz(
        uint128 _depositAmount,
        uint128 _shares,
        bool _defaultType,
        uint8 _type
    ) public {
        _previewMint_afterNoInterest(_depositAmount, _shares, _defaultType, _type);
        _assertPreviewMint(_shares, _defaultType, _type);
    }

    /*
    forge test -vv --ffi --mt test_maxMint_withInterest_fuzz
    */
    /// forge-config: core.fuzz.runs = 10000
    function test_maxMint_withInterest_fuzz(uint128 _shares, bool _defaultType, uint8 _type) public {
        vm.assume(_shares > 0);

        _createInterest();

        _assertPreviewMint(_shares, _defaultType, _type);
    }

    /*
    forge test -vv --ffi --mt test_maxBorrow_zero_fuzz
    */
    /// forge-config: core.fuzz.runs = 10000
    function test_maxBorrow_zero_fuzz(uint256 _assets, bool _useShares) public {
        assertEq(_useShares ? silo0.previewBorrowShares(_assets) : silo0.previewBorrow(_assets), _assets);
    }

    /*
    forge test -vv --ffi --mt test_maxBorrow_beforeInterest_fuzz
    */
    /// forge-config: core.fuzz.runs = 10000
    function test_maxBorrow_beforeInterest_fuzz(uint128 _assets, bool _useShares) public {
        uint256 assetsOrSharesToBorrow = _assets / 10 + (_assets % 2); // keep even/odd
        vm.assume(assetsOrSharesToBorrow < _assets);

        // can be 0 if _assets < 10
        if (assetsOrSharesToBorrow == 0) {
            _assets = 3;
            assetsOrSharesToBorrow = 1;
        }

        _createBorrowCase(_assets);

        uint256 preview = _useShares ? silo1.previewBorrowShares(assetsOrSharesToBorrow) : silo1.previewBorrow(assetsOrSharesToBorrow);
        uint256 result = _useShares ? _borrow(assetsOrSharesToBorrow, borrower) : _borrowShares(assetsOrSharesToBorrow, borrower);

        assertEq(preview, assetsOrSharesToBorrow, "previewBorrow shares are exact as amount when no interest");
        assertEq(preview, result, "previewBorrow - expect exact match");
    }

    /*
    forge test -vv --ffi --mt test_maxBorrow_withInterest
    */
    /// forge-config: core.fuzz.runs = 10000
    function test_maxBorrow_withInterest_fuzz(uint128 _assets, bool _useShares) public {
        uint256 assetsOrSharesToBorrow = _assets / 10 + (_assets % 2); // keep even/odd
        vm.assume(assetsOrSharesToBorrow < _assets);

        if (assetsOrSharesToBorrow == 0) {
            _assets = 3;
            assetsOrSharesToBorrow = 1;
        }

        _createBorrowCase(_assets);

        vm.warp(block.timestamp + 365 days);

        uint256 preview = _useShares ? silo1.previewBorrowShares(assetsOrSharesToBorrow) : silo1.previewBorrow(assetsOrSharesToBorrow);
        uint256 result = _useShares ? _borrowShares(assetsOrSharesToBorrow, borrower) : _borrow(assetsOrSharesToBorrow, borrower);

        assertEq(
            preview,
            result,
            string.concat(_useShares ? "[shares]" : "[assets]", " previewBorrow - expect exact match")
        );
    }

    /*
    forge test -vv --ffi --mt test_maxRepay_noInterestNoDebt_fuzz
    */
    /// forge-config: core.fuzz.runs = 10000
    function test_maxRepay_noInterestNoDebt_fuzz(uint128 _assetsOrShares, bool _useShares, bool _repayFull) public {
        uint128 amountToUse = _repayFull ? _assetsOrShares : uint128(uint256(_assetsOrShares) * 37 / 100);
        vm.assume(amountToUse > 0);

        // preview before debt creation
        uint256 preview = _useShares ? silo1.previewRepayShares(amountToUse) : silo1.previewRepay(amountToUse);

        _createDebt(_assetsOrShares, borrower);

        assertEq(preview, amountToUse, "previewRepay == assets == shares, when no interest");

        _assertPreviewRepay(preview, amountToUse, _useShares);
    }

    /*
    forge test -vv --ffi --mt test_maxRepayShares_noInterest_fuzz
    */
    /// forge-config: core.fuzz.runs = 10000
    function test_maxRepay_noInterest_fuzz(uint128 _assetsOrShares, bool _useShares, bool _repayFull) public {
        uint128 amountToUse = _repayFull ? _assetsOrShares : uint128(uint256(_assetsOrShares) * 37 / 100);
        vm.assume(amountToUse > 0);

        _createDebt(_assetsOrShares, borrower);

        uint256 preview = _useShares ? silo1.previewRepayShares(amountToUse) : silo1.previewRepay(amountToUse);

        assertEq(preview, amountToUse, "previewRepay == assets == shares, when no interest");

        _assertPreviewRepay(preview, amountToUse, _useShares);
    }

    /*
    forge test -vv --ffi --mt test_maxRepay_withInterest_fuzz
    */
    /// forge-config: core.fuzz.runs = 10000
    function test_maxRepay_withInterest_fuzz(uint128 _assetsOrShares, bool _useShares, bool _repayFull) public {
        uint128 amountToUse = _repayFull ? _assetsOrShares : uint128(uint256(_assetsOrShares) * 37 / 100);
        vm.assume(amountToUse > 0);

        _createDebt(_assetsOrShares, borrower);
        vm.warp(block.timestamp + 100 days);

        uint256 preview = _useShares ? silo1.previewRepayShares(amountToUse) : silo1.previewRepay(amountToUse);

        _assertPreviewRepay(preview, amountToUse, _useShares);
    }

    /*
    forge test -vv --ffi --mt test_maxWithdraw_noInterestNoDebt_fuzz
    */
    /// forge-config: core.fuzz.runs = 10000
    function test_maxWithdraw_noInterestNoDebt_fuzz(uint128 _assetsOrShares, bool _doRedeem, bool _partial) public {
        uint128 amountToUse = _partial ? uint128(uint256(_assetsOrShares) * 37 / 100) : _assetsOrShares;
        vm.assume(amountToUse > 0);

        // preview before deposit creation
        uint256 preview = _doRedeem ? silo0.previewRedeem(amountToUse) : silo0.previewWithdraw(amountToUse);

        _deposit(_assetsOrShares, depositor);

        assertEq(preview, amountToUse, "previewWithdraw == assets == shares, when no interest");

        _assertPreviewWithdraw(preview, amountToUse, _doRedeem);
    }

    /*
    forge test -vv --ffi --mt test_maxWithdraw_noDebt_fuzz
    */
    /// forge-config: core.fuzz.runs = 10000
    function test_maxWithdraw_noDebt_fuzz(uint128 _assetsOrShares, bool _doRedeem, bool _partial) public {
        uint128 amountToUse = _partial ? uint128(uint256(_assetsOrShares) * 37 / 100) : _assetsOrShares;
        vm.assume(amountToUse > 0);

        _deposit(uint256(_assetsOrShares) * 2 - (_assetsOrShares % 2), depositor);

        uint256 preview = _doRedeem ? silo0.previewRedeem(amountToUse) : silo0.previewWithdraw(amountToUse);

        assertEq(preview, amountToUse, "previewWithdraw == assets == shares, when no interest");

        _assertPreviewWithdraw(preview, amountToUse, _doRedeem);
    }

    /*
    forge test -vv --ffi --mt test_maxWithdraw_debt_fuzz
    */
    /// forge-config: core.fuzz.runs = 10000
    function test_maxWithdraw_debt_fuzz(uint128 _assetsOrShares, bool _doRedeem, bool _interest, bool _partial) public {
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

    function _assertPreviewRepay(uint256 _preview, uint128 _assetsOrShares, bool _useShares) internal {
        vm.assume(_preview > 0);

        uint256 repayResult = _useShares
            ? _repayShares(type(uint256).max, _assetsOrShares, borrower)
            : _repay(_assetsOrShares, borrower);

        assertGt(repayResult, 0, "expect any repay amount > 0");

        assertEq(
            _preview,
            repayResult,
            string.concat(_useShares ? "[shares]" : "[amount]", " preview should give us exact repay result")
        );
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

    function _assertWeCanNotDepositMore(ISilo _silo, address _user) internal {
        MintableToken token = address(_silo) == address(silo0) ? token0 : token1;
        uint256 one = 1;

        // after max, we can not deposit even 1 wei
        // we can not mint, because we max out, so we transfering
        vm.prank(address(_silo));
        token.transfer(_user, one);

        vm.startPrank(_user);
        token.approve(address(_silo), one);
        vm.expectRevert(); // we can not mint shares
        _silo.deposit(one, _user);
        vm.stopPrank();
    }
}
